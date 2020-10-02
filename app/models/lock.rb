require 'redis'
require 'connection_pool'
require 'yaml'
require 'concurrent'

class Lock

  UPGRADE_LOCK ||= 'Upgrade'
  INTACCT_DETAILS_PARSER ||= 'IntacctParser'
  TRADE_CARD_PARSER ||= 'TradecardParser'
  ALLIANCE_DAY_END_PROCESS ||= 'AllianceDayEnd'

  def self.create_connection_pool
    config = redis_config
    ConnectionPool.new(size: (config[:pool_size] ? config[:pool_size] : 10), timeout: 60) do
      get_redis_client config
    end
  end
  private_class_method :create_connection_pool

  def self.redis_config
    config = MasterSetup.secrets["redis"]
    raise "No configuration found under the 'redis' key in secrets.yml." if config.blank?
    config = config.with_indifferent_access
  end
  private_class_method :redis_config

  def self.get_redis_client config
    redis = Redis.new(host: config[:server], port: config[:port])
  end
  private_class_method :get_redis_client

  def self.get_connection_pool
    @@connection_pool ||= create_connection_pool()
    @@connection_pool
  end
  private_class_method :get_connection_pool

  def self.ensure_redis_access
    get_connection_pool.with(timeout: 5) do |redis|
      redis.exists?("test")
    end
    true
  rescue Redis::CannotConnectError, Redis::ConnectionError, Timeout::Error, Redis::TimeoutError => e
    config = redis_config
    raise "Redis does not appear to be running.  Please ensure it is installed and running at #{config[:server]}:#{config[:port]}."
  end

  # Acquires a mutually exclusive, cross process/host, named lock (mutex)
  # for the duration of the block passed to this method returning whatever
  # the yielded block returns.
  #
  # This means that while this process is running the block no other process for the entire
  # application can execute the same code - they will all block till this process has completed
  # the block.
  #
  # In other words, use this locking mechanism judiciously and keep the execution time low for the
  # block you pass in.
  #
  # Be aware, by default, the duration of the lock is only 3 minutes.  You can extend this by
  # passing a longer # of seconds in the lock_expiration option.
  #
  # options accepted:
  #
  # timeout - The amount of time to wait for the lock before failing (defaults to 60).  No retries are attempted.  If you want to wait
  # longer than the 60 second default than pass a longer timeout value.  A Timeout::Error is raised when a timeout occurs
  #
  # yield_in_transaction - If true (default), the method yields to the given block inside an open database transaction.  Pass
  # false if you don't want this.  This is done largely for backwards compatibility with the old DB locking scheme.
  #
  # lock_expiration - The amount of time in seconds before the lock is reaped by the lock server.  This is largely here
  # to ensure that failed clients don't lock out others indefinitely. Defaults to 300.  Note, if the process is still
  # running, the lock will continue to lock..it will not simply time out after 300 seconds.
  #
  # raise_timeout - If true (defaults to true), then a timeout is raised if the lock could not be obtained inside the given
  # timeout period.  You might want this to be false for processes that are run fairly often and if they can't get a lock
  # in a certain period, then it doesn't really matter since they're run again shortly.
  #
  # auto_extend_lock_period - If true (defaults to false), then the lock timeout running in redis will be automatically extended
  # for as long as the block passed to acquire is running for.
  def self.acquire(lock_name, opts = {}, &block)
    internal_lock_name = clean_lock_name(lock_name)
    already_acquired = definitely_acquired?(internal_lock_name)

    # The whole concept of temp locks is largely moot w/ redis...given the temporal nature of its "database"
    # We're going to reverse the understanding (mostly to guard against dying processes leaving locks permanently locked)
    # and if you want a PERMANENT lock, you will need to explicitly pass nil for lock_expiration
    # The VAST majority of time we're using this lock construct is for things that take seconds at most, so
    # we won't have to retrofit any external callsites with this change
    opts = {timeout: 60, yield_in_transaction: true, lock_expiration: 300, raise_timeout: true, auto_extend_lock_period: false}.merge opts

    yield_in_transaction = opts[:yield_in_transaction] == true
    result = nil

    if already_acquired
      result = execute_block yield_in_transaction, &block
    else
      timeout = opts[:timeout]
      connection_timeout_at = Time.zone.now + timeout.seconds
      begin
        get_connection_pool.with(timeout: timeout) do |redis|
          raise Timeout::Error if Time.zone.now > connection_timeout_at

          result = do_locking redis, internal_lock_name, connection_timeout_at, opts[:auto_extend_lock_period], opts[:lock_expiration], yield_in_transaction, &block
        end
      rescue Timeout::Error, Redis::TimeoutError => e
        # Just catch and re-raise the error after normalize the message (since we raise an error and the connection pool/redis potentially raises one)
        maybe_raise_timeout(opts[:raise_timeout], "Waited #{timeout} #{"second".pluralize(timeout)} while attempting to acquire lock '#{lock_name}'.", e.backtrace)
      rescue Redis::CannotConnectError, Redis::ConnectionError => e
        # In this case, the attempt to connect to redis for the lock failed (server restart/maint etc)..keep retrying until we've waiting longer than
        # the given timeout.
        if (Time.zone.now) < connection_timeout_at
          sleep(1)
          retry
        else
          maybe_raise_timeout(opts[:raise_timeout], "Waited #{timeout} #{"second".pluralize(timeout)} while attempting to connect to lock server for lock '#{lock_name}'.", e.backtrace)
        end
      ensure
        release_lock(internal_lock_name)
      end
    end

    result
  end

  def self.do_locking redis, lock_name, connection_timeout_at, auto_extend_lock_period, lock_auto_exiration_seconds, yield_in_transaction, &block
    lock_manager = Redlock::Client.new [redis]
    lock_info = nil
    lock_auto_exiration_millis = lock_auto_exiration_seconds * 1000
    begin
      lock_info = lock_manager.lock(lock_name, lock_auto_exiration_millis)
      # lock_info is boolean false if the manager lock call failed to acquire the lock
      unless lock_info
        if Time.zone.now > connection_timeout_at
          raise Timeout::Error
        else
          sleep(0.3)
        end
      end
    end while !lock_info

    block_completed = false

    # The thread will extend the life of the lock again if the block below runs for longer than given expiration time
    # If the lock expiration is anything <= 5 seconds, then we're not going to even bother running this
    outer_thread = Thread.current.object_id
    if auto_extend_lock_period && lock_auto_exiration_seconds >= 5
      sync_lock = Concurrent::Synchronization::Lock.new
      relock_thread = Thread.new {
        until block_completed
          sync_lock.wait(lock_auto_exiration_seconds / 2)
          if !block_completed
            lock_manager.lock(lock_name, lock_auto_exiration_millis, extend: lock_info)
          end
        end
      }
    end

    begin
      acquired_lock(lock_name)
      result = execute_block yield_in_transaction, &block
    ensure
      block_completed = true
      sync_lock.signal if sync_lock
      lock_manager.unlock lock_info
      relock_thread.join if relock_thread
    end

    result
  end

  def self.clean_lock_name lock_name
    # If the lock IS UTF-8, strip any invalid chars...these seem to sometimes crop up when we're
    # parsing data from untrusted sources and using it for key values (like in imported file spreadsheets, csv files, etc.)
    # We don't really care that the lock name has bad UTF-8 chars in it...let that get handled elsewhere
    # All we care about here is that the mutex lock is established.
    if lock_name.encoding && lock_name.encoding.name != "UTF-8"
      # If the lock isn't UTF-8, convert it to that (for the redis ruby client's sake).
      lock_name = lock_name.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    end

    if !lock_name.valid_encoding?
      lock_name = lock_name.chars.select(&:valid_encoding?).join
    end

    # We're also going to tack on information about the instance to effectively namespace the keys since we're
    # using one single Redis instance across all systems.
    "#{MasterSetup.instance_identifier}:#{lock_name}"
  end
  private_class_method :clean_lock_name

  def self.maybe_raise_timeout should_raise, message, backtrace
    return unless should_raise

    if backtrace.nil?
      raise Timeout::Error, message
    else
      raise Timeout::Error, message, backtrace
    end
  end

  def self.acquire_for_class klass, opts={}
    return self.acquire(klass.name, opts) {yield}
  end

  def self.execute_block with_transaction
    if with_transaction
      ActiveRecord::Base.transaction { return yield}
    else
      return yield
    end
  end

  # if true, the lock is already acquired
  def self.definitely_acquired?(name)
    !!Thread.current[:definitely_acquired_locks] and Thread.current[:definitely_acquired_locks].has_key?(name)
  end
  private_class_method :definitely_acquired?

  def self.acquired_lock(name)
    Thread.current[:definitely_acquired_locks] ||= {}
    Thread.current[:definitely_acquired_locks][name] = true
  end
  private_class_method :acquired_lock

  def self.release_lock(name)
    Thread.current[:definitely_acquired_locks] ||= {}
    Thread.current[:definitely_acquired_locks].delete(name)
  end
  private_class_method :release_lock

  def self.unlocked?(lock_name)
    # this is solely used in the unit tests
    # It's reaching into redlock-rb a bit, but it's here to make
    # sure the locks are being cleared as expected
    lock_name = clean_lock_name(lock_name)

    get_connection_pool.with do |redis|
      return !redis.exists?(lock_name)
    end
  end
  private_class_method :unlocked?

  def self.clear_lock lock_name
    # use this only if you need to forcibly clear a lock (say from the command line).
    lock_name = clean_lock_name(lock_name)

    val = nil
    get_connection_pool.with(timeout: 30) do |redis|
      val = redis.del lock_name
    end

    val == 1
  end
  private_class_method :clear_lock

  def self.flushall force = false
    # This method blows up the whole redis database...don't use it for anything other than tests
    raise "Only available in testing environment" unless Rails.env.test? || force
    get_connection_pool.with do |redis|
      redis.flushall
    end
  end
  private_class_method :flushall

  def self.lock_wait_timeout? exception
    # Unfortunately, active record (or mysql adapter) uses a single error for all database errors
    # so the only real way of determining issues is by examing the error message
    exception.message && !(exception.message =~ /Error: Lock wait timeout exceeded/).nil?
  end

  # This method basically just attempts to call with_lock on the passed in object
  # up to max_retry_count times handling any lock wait timeouts that may occur in the
  # time being.
  # Be careful, the with_lock call used here WILL RELOAD the locked object's data fresh from the DB
  # and it WILL overwrite any unsaved data you have in the object at the time this method is called.
  #
  # See ActiveRecord::Locking::Pessimistic.lock! for explanation of lock_clause
  def self.with_lock_retry object_to_lock, lock_clause = true, max_retry_count = 4
    counter = 0
    active_transaction = inside_nested_transaction?
    begin
      object_to_lock.with_lock(lock_clause) do
        return yield
      end
    rescue ActiveRecord::StatementInvalid => e
      raise e if active_transaction

      retry if Lock.lock_wait_timeout?(e) && ((counter += 1) <= max_retry_count)

      raise e
    end
  end
  # There's no class level 'alias' method in ruby, this is the equivalent
  singleton_class.send(:alias_method, :db_lock, :with_lock_retry)

  def self.inside_nested_transaction?
    ActiveRecord::Base.connection.open_transactions > 0
  end

end

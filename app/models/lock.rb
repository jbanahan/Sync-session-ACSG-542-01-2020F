require 'redis'
require 'redis-semaphore'
require 'redis-namespace'
require 'connection_pool'
require 'yaml'

# Code taken from https://makandracards.com/makandra/1026-simple-database-mutex-mysql-lock

# Every distinct lock name used creates a new row in the locks table.  These rows are not
# removed.
#
# I'm starting to realize this whole locking scheme is really quite hacky (especially after having
# to add in all the deadlock detetion and retrys.  It probably should
# really instead by implemented w/ some sort of real distributed mutex/semaphore
# system.
#
# Something like this would be preferable as the locking engine: https://github.com/dv/redis-semaphore (side bonues - Redis is also available as a AWS ElastiCache engine)
# This would also work: https://github.com/songkick/mega_mutex
class Lock

  FENIX_PARSER_LOCK ||= 'FenixParser'
  UPGRADE_LOCK ||= 'Upgrade'
  ISF_PARSER_LOCK ||= 'IsfParser'
  RL_PO_PARSER_LOCK ||= 'RLPoParser'
  ALLIANCE_PARSER ||= 'AllianceParser'
  FENIX_INVOICE_PARSER_LOCK ||= 'FenixInvoiceParser'
  INTACCT_DETAILS_PARSER ||= 'IntacctParser'
  TRADE_CARD_PARSER ||= 'TradecardParser'
  ALLIANCE_DAY_END_PROCESS ||= 'AllianceDayEnd'

  def self.create_connection_pool
    config = YAML.load_file('config/redis.yml')[Rails.env]
    raise "No configuration found for #{Rails.env} in config/redis.yml" unless config

    config = config.with_indifferent_access
    ConnectionPool.new(size: (config[:pool_size] ? config[:pool_size] : 10), timeout: 60) do 
      get_redis_client config
    end
  end
  private_class_method :create_connection_pool

  def self.get_redis_client config
    redis = Redis.new(host: config[:server], port: config[:port])

    # Now we need to make sure we're namespacing so we don't cross lock with other instances or versions
    # We're not persisting our redis store and we don't really run jobs across differing versions
    Redis::Namespace.new("#{Rails.root.basename}", redis: redis)
  end
  private_class_method :get_redis_client

  def self.get_connection_pool
    @@connection_pool ||= create_connection_pool()
    @@connection_pool
  end
  private_class_method :get_connection_pool

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
  # to ensure that failed clients don't lock out others indefinitely.  You MAY pass nil for this value to utilize 
  # indifinite locks, but that's probably not entirely wise (if an indefinite lock happens and is blocking for too long
  # it can be cleared by using the release_stale_locks! method of Redis::Semaphore).
  def self.acquire(lock_name, opts = {})
    already_acquired = definitely_acquired?(lock_name)

    # The whole concept of temp locks is largely moot w/ redis...given the temporal nature of its "database"
    # We're going to reverse the understanding (mostly to guard against dying processes leaving locks permanently locked)
    # and if you want a PERMANENT lock, you will need to explicitly pass nil for lock_expiration
    # The VAST majority of time we're using this lock construct is for things that take seconds at most, so 
    # we won't have to retrofit any external callsites with this change
    opts = {timeout: 60, yield_in_transaction: true, lock_expiration: 300}.merge opts

    yield_in_transaction = opts[:yield_in_transaction] == true
    result = nil
    if already_acquired
      result = execute_block yield_in_transaction, &Proc.new
    else
      timeout = opts[:timeout]
      semaphore = nil
      begin
        get_connection_pool.with(timeout: timeout) do |redis|
          # We're going to expire temp locks in 10 minutes, this is really just housekeeping so that 
          # we don't build up vast amounts of temp keys for now purpose.  This just tells redis to 
          # reap the lock name after 5 minutes..if another lock tries to re-use the name, then 
          # the expire time is updated to 5 minutes after that new call.
          semaphore = opts[:lock_expiration] ? Redis::Semaphore.new(lock_name, redis: redis, expiration: opts[:lock_expiration]) : Redis::Semaphore.new(lock_name, redis: redis)
          # The lock call denotes a timeout by returning false, but it will also return the result of the block
          # So, to avoid cases where we potentially have the block returning false and the lock returning false
          # just assume that if the lock's block isn't yielded to that the lock timed out.
          timed_out = true
          semaphore.lock(timeout) do 
            timed_out = false
            acquired_lock(lock_name)
            result = execute_block yield_in_transaction, &Proc.new
          end

          raise Timeout::Error if timed_out
        end
      rescue Timeout::Error => e
        # Just catch and re-raise the error after normalize the message (since we raise an error and the connection pool potentially raises one)
        raise Timeout::Error, "Waited #{timeout} #{"second".pluralize(timeout)} while attempting to acquire lock '#{lock_name}'.", e.backtrace
      ensure
        release_lock(lock_name)
      end
    end

    result
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

  def self.acquired_lock(name)
    Thread.current[:definitely_acquired_locks] ||= {}
    Thread.current[:definitely_acquired_locks][name] = true
  end

  def self.release_lock(name)
    Thread.current[:definitely_acquired_locks] ||= {}
    Thread.current[:definitely_acquired_locks].delete(name)
  end

  def self.unlocked?(lock_name)
    # this is solely used in the unit tests
    # It's reaching into redis-semaphore a bit, but it's here to make
    # sure the locks are being cleared as expected
    get_connection_pool.with do |redis|
      return redis.lrange("#{lock_name}:AVAILABLE", 0, -1).length > 0
    end
  end

  def self.expires_in(lock_name)
    # this is solely used in the unit tests
    # It's reaching into redis-semaphore a bit, but it's here to make
    # sure the expiration is working as expected
    get_connection_pool.with do |redis|
      return redis.ttl("#{lock_name}:EXISTS")
    end
  end

  def self.flushall force = false
    # This method blows up the whole redis database...don't use it for anything other than tests
    raise "Only available in testing environment" unless Rails.env.test? || force
    get_connection_pool.with do |redis|
      redis.redis.flushall
    end
  end

  private_class_method :acquired_lock, :release_lock, :expires_in, :unlocked?, :flushall

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

  def self.inside_nested_transaction?
    ActiveRecord::Base.connection.open_transactions > 0
  end

end
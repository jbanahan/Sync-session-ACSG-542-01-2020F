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
class Lock < ActiveRecord::Base

  FENIX_PARSER_LOCK ||= 'FenixParser'
  UPGRADE_LOCK ||= 'Upgrade'
  ISF_PARSER_LOCK ||= 'IsfParser'
  RL_PO_PARSER_LOCK ||= 'RLPoParser'
  ALLIANCE_PARSER ||= 'AllianceParser'
  FENIX_INVOICE_PARSER_LOCK ||= 'FenixInvoiceParser'
  INTACCT_DETAILS_PARSER ||= 'IntacctParser'
  TRADE_CARD_PARSER ||= 'TradecardParser'
  ALLIANCE_DAY_END_PROCESS ||= 'AllianceDayEnd'

  PERMENANT_LOCKS = Set.new

  # Acquires a mutually exclusive, cross process/host, named lock (mutex)
  # for the duration of the block passed to this method returning wahtever
  # the yielded block returns.
  #
  # This means that while this process is running the block no other process for the entire
  # application can execute the same code - they will all block till this process has completed
  # the block.
  #
  # In other words, use this locking mechanism judiciously and keep the execution time low for the 
  # block you pass in.
  # 
  # options accepted:
  # times- The number of times to retry after lock wait failure attempts (failures are currently 60 seconds in DB)
  # temp_lock - If true, the lock record created will be removed after it is utilized.
  def self.acquire(name, opts = {})
    already_acquired = definitely_acquired?(name)

    opts = {:times => 0, :temp_lock => false}.merge opts

    result = nil
    if already_acquired
      result = yield
    else
      # The outer block is solely for handling the potential for the lock missing error / retry
      # on the temp locks.
      my_lock = nil
      begin
        # When dealing w/ long running processes and permanent locks, record if this process has seen them 
        # before and just skip the create part next time
        if opts[:temp_lock] == true || !PERMENANT_LOCKS.include?(name)
          begin
            create! name: name
            PERMENANT_LOCKS << name unless opts[:temp_lock] == true
          rescue ActiveRecord::RecordNotUnique
            # concurrent create is okay since there's a unique index on the name attribute
          rescue ActiveRecord::StatementInvalid => e
            retry if lock_deadlock?(e)
          end
        end
        
        counter = 0
        begin
          transaction do
            my_lock = find_by_name(name, :lock => true) # this is the call that will block in concurrent Lock.acquire attempts
            # The lock could technically have been removed since it was initially created (like if multiple temp locks are being
            # attempted for the same key)..if so, just retry
            raise LockMissingError, name unless my_lock
            acquired_lock(name)
            result = yield
            my_lock.delete if opts[:temp_lock] == true && !my_lock.nil?
            my_lock = nil
          end
        rescue ActiveRecord::StatementInvalid => e
          # We only want to retry acquiring the lock, we don't want to retry the 
          # actual code inside the yielded block.
          if !definitely_acquired?(name)
            retry if lock_wait_timeout?(e) && (counter += 1) <= opts[:times]

            # Only retry lock aquisition deadlocks...don't retry delete ones since if the delete deadlocked
            # then the yield block ran, and we don't want to retry that.  I don't think there should be a deadlock
            # on the delete anyway since we should have an exclusive lock on the record at the point of the delete call
            # anyway.
            retry if lock_deadlock? e, false
          end

          raise e
        ensure
          maybe_released_lock(name)
          # This follow-up check needs to be outside the inner transaction because if the yield block blows up it'll
          # roll back the transaction (nullifying any delete occurring inside it)
          begin
            my_lock.delete if opts[:temp_lock] == true && !my_lock.nil?
          rescue ActiveRecord::StatementInvalid => e
            retry if lock_deadlock? e
          end
        end
      rescue LockMissingError
        # If we're missing a permanent lock (shouldn't happen, but could if someone accidently clears the db)
        # clear the permanent locks Set so we don't get caught in a loop
        PERMENANT_LOCKS.clear unless opts[:temp_lock] == true
        retry
      end
    end

    result
  end

  def self.lock_deadlock? e, include_delete = true
    msg = e.message
    deadlock = (msg =~ /deadlock found/i && (msg =~ /select\s+`locks`./i || msg =~ /insert into `locks`/i || (include_delete && msg =~ /delete from `locks`/i )))
    sleep(Random.rand(0.05..0.20)) if deadlock
    deadlock
  end

  # if true, the lock is acquired
  # if false, the lock might still be acquired, because we were in another db transaction
  def self.definitely_acquired?(name)
    !!Thread.current[:definitely_acquired_locks] and Thread.current[:definitely_acquired_locks].has_key?(name)
  end

  def self.acquired_lock(name)
    Thread.current[:definitely_acquired_locks] ||= {}
    Thread.current[:definitely_acquired_locks][name] = true
  end

  def self.maybe_released_lock(name)
    Thread.current[:definitely_acquired_locks] ||= {}
    Thread.current[:definitely_acquired_locks].delete(name)
  end

  def self.lock_wait_timeout? exception
    # Unfortunately, active record (or mysql adapter) uses a single error for all database errors
    # so the only real way of determining issues is by examing the error message
    exception.message && !(exception.message =~ /Error: Lock wait timeout exceeded/).nil?
  end

  private_class_method :acquired_lock, :maybe_released_lock

  # This method basically just attempts to call with_lock on the passed in object
  # up to max_retry_count times handling any lock wait timeouts that may occur in the 
  # time being.
  # Be careful, the with_lock call used here WILL RELOAD the locked object's data fresh from the DB
  # and it WILL overwrite any unsaved data you have in the object at the time this method is called.
  #
  # See ActiveRecord::Locking::Pessimistic.lock! for explanation of lock_clause
  def self.with_lock_retry object_to_lock, lock_clause = true, max_retry_count = 4
    counter = 0
    begin
      object_to_lock.with_lock(lock_clause) do 
        return yield
      end
    rescue ActiveRecord::StatementInvalid => e
      retry if Lock.lock_wait_timeout?(e) && ((counter += 1) <= max_retry_count)

      raise e
    end
  end

  class LockMissingError < StandardError; end

end
# Code taken from https://makandracards.com/makandra/1026-simple-database-mutex-mysql-lock

# Every distinct lock name used creates a new row in the locks table.  These rows are not
# removed.
class Lock < ActiveRecord::Base

  FENIX_PARSER_LOCK ||= 'FenixParser'
  UPGRADE_LOCK ||= 'Upgrade'
  ISF_PARSER_LOCK ||= 'IsfParser'
  RL_PO_PARSER_LOCK ||= 'RLPoParser'

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
        begin
          create(:name => name) unless find_by_name(name)
        rescue ActiveRecord::RecordNotUnique
          # concurrent create is okay since there's a unique index on the name attribute
        end

        counter = 0
        begin
          transaction do
            my_lock = find_by_name(name, :lock => true) # this is the call that will block in concurrent Lock.acquire attempts
            # The lock could technically have been removed since it was initially created and here..if so, just retry
            raise LockMissingError, name unless my_lock
            acquired_lock(name)
            result = yield
          end
        rescue ActiveRecord::StatementInvalid => e
          # We only want to retry acquiring the lock, we don't want to retry the 
          # actual code inside the yielded block.
          unless definitely_acquired?(name)
            retry if lock_wait_timeout?(e) && (counter += 1) <= opts[:times]
          end

          raise e
        ensure
          maybe_released_lock(name)
          # This needs to be outside the inner transaction because if the yield block blows up it'll
          # roll back the transaction (nullifying any delete occurring inside it)
          my_lock.destroy if opts[:temp_lock] == true
        end
      rescue LockMissingError
        retry
      end
    end

    result
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
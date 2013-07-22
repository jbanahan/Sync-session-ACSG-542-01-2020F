# Code taken from https://makandracards.com/makandra/1026-simple-database-mutex-mysql-lock

# Every distinct lock name used creates a new row in the locks table.  These rows are not
# removed.
class Lock < ActiveRecord::Base

  FENIX_PARSER_LOCK ||= 'FenixParser'
  UPGRADE_LOCK ||= 'Upgrade'

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
  def self.acquire(name)
    already_acquired = definitely_acquired?(name)

    result = nil
    if already_acquired
      result = yield
    else
      begin
        create(:name => name) unless find_by_name(name)
      rescue ActiveRecord::StatementInvalid
        # concurrent create is okay since there's a unique index on the name attribute
      end

      begin
        transaction do
          find_by_name(name, :lock => true) # this is the call that will block in concurrent Lock.acquire attempts
          acquired_lock(name)
          result = yield
        end
      ensure
        maybe_released_lock(name) 
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
    logger.debug("Acquired lock '#{name}'")
    Thread.current[:definitely_acquired_locks] ||= {}
    Thread.current[:definitely_acquired_locks][name] = true
  end

  def self.maybe_released_lock(name)
    logger.debug("Released lock '#{name}' (if we are not in a bigger transaction)")
    Thread.current[:definitely_acquired_locks] ||= {}
    Thread.current[:definitely_acquired_locks].delete(name)
  end

  private_class_method :acquired_lock, :maybe_released_lock

end
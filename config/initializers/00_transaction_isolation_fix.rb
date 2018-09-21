if ActiveRecord::VERSION::MAJOR == 3
  # This is a fix for a bug in the transaction isolation, that incorrectly calls the wrapped exception constructor
  # It can be remove if this PR is accepted and the project updated (https://github.com/qertoip/transaction_isolation/pull/7) 
  # OR if we move off ActiveRecord 3
  module ActiveRecord; class TransactionIsolationConflict < ::ActiveRecord::WrappedDatabaseException
    def initialize message, original_error = nil
      super(message, original_error)
    end
  end; end
  
end
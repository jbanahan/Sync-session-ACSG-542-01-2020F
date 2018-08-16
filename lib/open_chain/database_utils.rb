module OpenChain; class DatabaseUtils

  def self.deadlock_error? error
    # Stupid ActiveRecord wraps basically every database exception sent as part of a query in a StatementInvalid error,
    # Which means we have to tease the underlying exception out of the error message.  REALLY wish they'd provide a way 
    # to get at the underlying error from the database driver.
    if error.is_a?(ActiveRecord::StatementInvalid)
      case error.message
      when /Mysql2::Error/
        return mysql_deadlock_error?(error)
      else
        return false
      end
    elsif error.is_a?(Mysql2::Error)
      mysql_deadlock_error?(error)
    else
      return false
    end
  end

  def self.mysql_deadlock_error? error
    [ "Deadlock found when trying to get lock",
      "Lock wait timeout exceeded"].any? do |error_message|
      error.message =~ /#{Regexp.escape( error_message )}/i
    end
  end
  private_class_method :mysql_deadlock_error?

end; end;
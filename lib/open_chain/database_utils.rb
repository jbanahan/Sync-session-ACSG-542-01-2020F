module OpenChain; class DatabaseUtils

  def self.deadlock_error? error
    if error.is_a?(Mysql2::Error)
      [ "Deadlock found when trying to get lock",
        "Lock wait timeout exceeded"].any? do |error_message|
        error.message =~ /#{Regexp.escape( error_message )}/i
      end
    else
      return false
    end
  end

end; end;
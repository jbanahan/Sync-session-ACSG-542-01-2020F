class UserSession < Authlogic::Session::Base
  
  find_by_login_method :find_not_locked
  generalize_credentials_error_messages "Your login was not successful."
  # Fix 
  include ActiveModel::Conversion 
  def persisted? 
    false 
  end 
  # End of fix 
  
end

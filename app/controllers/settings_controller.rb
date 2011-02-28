class SettingsController < ApplicationController
  
  def index
    admin_secure("Only administrators can adjust system settings.") {}    
  end
  
end

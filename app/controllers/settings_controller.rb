class SettingsController < ApplicationController
  
  def index
    admin_secure("Only administrators can adjust system settings.") { 
      render layout:false 
    }    
  end
  
  def tools
    render :layout=>'one_col'
  end

  def setup
  end
  
end

class SettingsController < ApplicationController
  
  def index
    admin_secure("Only administrators can adjust system settings.") {}    
  end
  
  def active_users
    admin_secure("Only administrators can view this page.") {
      @users = User.where("last_request_at > ?",30.minutes.ago).order("last_request_at DESC").paginate(:per_page=>20, :page=>params[:page])
    }
  end

  def tools

  end

end

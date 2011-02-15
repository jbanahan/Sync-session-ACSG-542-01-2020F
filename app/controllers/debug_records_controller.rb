class DebugRecordsController < ApplicationController
  def index
    sys_admin_secure {
      @user = User.find(params[:user_id])
      @debug_records = DebugRecord.where(:user_id => params[:user_id]).order("debug_records.created_at ASC")
    }
  end

  def show
    sys_admin_secure {
      @user = User.find(params[:user_id])
      @debug_record = DebugRecord.find(params[:id])
    }
  end

  def destroy_all
    sys_admin_secure {
      user = User.find(params[:user_id])
      if DebugRecord.where(:user_id=>params[:user_id]).destroy_all
        add_flash :notices, "All debug records for user were destroyed."
        redirect_to company_user_path(user.company,user)
      else
        add_flash :errors, "Debug records were not successfully destroyed."
        redirect_to compan_user_debug_records(user.company,user)
      end
    }
  end

end

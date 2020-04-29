class AwsBackupSessionsController < ApplicationController
  SEARCH_PARAMS = {
    'name' => {:field => 'name', :label=> 'Name'},
    'start_time' => {:field => 'start_time', :label => 'Start Time'},
    'end_time' => {:field => 'end_time', :label => 'End Time'},
    'log' => {:field => 'log', :label => 'Log'},
    'created_at' => {:field => 'created_at', :label => "Created At"}
  }

  def set_page_title
    @page_title = 'Tools'
  end
  def index
    sys_admin_secure {
      sp = SEARCH_PARAMS.clone
      s = build_search(sp, 'log', 'created_at', 'd')
      @aws_backup_sessions = s.paginate(:per_page => 20, :page => params[:page])
      render :layout => 'one_col'
    }
  end

  def show
    sys_admin_secure {
      @aws_backup_session = AwsBackupSession.find(params[:id])
    }
  end

  private

  def secure
    AwsBackupSession.find_can_view(current_user)
  end
end

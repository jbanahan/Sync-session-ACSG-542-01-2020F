class FtpSessionsController < ApplicationController
  SEARCH_PARAMS = {
    'c_username' => {:field => 'username', :label=> 'Username'},
    'c_server' => {:field => 'server', :label => 'Server'},
    'c_filename' => {:field => 'file_name', :label => 'File Name'},
    'd_createdat' => {:field => 'created_at', :label => "Created At"},
    'd_sentdat' => {:field => 'updated_at', :label => "Sent At"}
  }

  def index
    sys_admin_secure {
      sp = SEARCH_PARAMS.clone
      s = build_search(sp, 'c_filename', 'd_createdat', 'd')
      # No field has been selected...ie it's the initial page load
      if params[:f].blank?
        s = s.where("created_at > ?", Time.zone.now.beginning_of_day)
        @default_display = "By default, only FTP Sessions from today are displayed when no search fields are utilized."
      end
      respond_to do |format|
          format.html {
              @ftp_sessions = s.paginate(:per_page => 40, :page => params[:page])
              render :layout => 'one_col'
          }
      end
    }
  end

  def show
    sys_admin_secure {
      @ftp_session = FtpSession.find(params[:id])
      respond_to do |format|
        format.html # show.html.erb
      end
    }
  end

  def download
    sys_admin_secure {
      @ftp_session = FtpSession.find(params[:id])
      if @ftp_session.nil?
        add_flash :errors, "File could not be found."
        redirect_to request.referrer
      else
        send_data @ftp_session.data, 
        :filename => @ftp_session.file_name,
        # :type => @ftp_session.file_type,
        :disposition => 'attachment'
      end
    }
  end

  private 
  def secure
    FtpSession.find_can_view(current_user)
  end
end

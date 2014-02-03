class ErrorLogEntriesController < ApplicationController
  def index
    sys_admin_secure {
      @error_entries = ErrorLogEntry.order("id desc").paginate(:per_page=>20, :page=>params[:page])
    }
  end

  def show 
    sys_admin_secure {
      @error_log_entry = ErrorLogEntry.find params[:id]
    }
  end

  def log_angular
    begin
      raise "Angular JS Error"
    rescue
      $!.log_me [params[:exception],"REFERRER: #{request.referrer}"]
    end
    render text: 'ok'
  end
end

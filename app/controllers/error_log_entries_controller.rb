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
    StandardError.new('Angular Error').log_me [params[:exception],"REFERRER: #{request.referrer}"]
    render text: 'ok'
  end
end

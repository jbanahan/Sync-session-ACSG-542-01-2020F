class BulkProcessLogsController < ApplicationController

  def show
    secure { |log|
      @bulk_process_log = log
      @change_records = log.change_records.paginate(:per_page=>50,:page=>params[:page])
    }
  end

  def messages
    secure { |log|
      cr = ChangeRecord.find params[:cr_id]
      msgs = cr.change_record_messages.collect {|m| m.message}
      render :json=>msgs.to_json
    }
  end

  private
    def secure
      log = BulkProcessLog.find params[:id]
      action_secure(log.can_view?(current_user),log,{:lock_check=>false,:verb=>"view",:module_name=>"Log"}) {
        yield log
      }
    end
end
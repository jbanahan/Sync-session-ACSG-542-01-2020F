class FileImportResultsController < ApplicationController

  def show
    secure {
      @change_records = @file_import_result.change_records.paginate(:per_page=>50,:page=>params[:page])
    }
  end

  def messages
    secure {
      cr = ChangeRecord.find params[:cr_id]
      msgs = cr.change_record_messages.collect {|m| m.message}
      render :json=>msgs.to_json
    }
  end

  def download_failed
    #Note on the name: this means the user wants to download change records that failed, not that some download method has actually failed
    secure{
      @fir = FileImportResult.find(params[:id])
      if @fir.change_records.length > 200
        @fir.delay.download_results(false, current_user.id, true)
        flash[:notices] = ["You will receive a system message when your file is finished processing."]
        redirect_to :back
      else
        att = @fir.download_results(false, current_user.id)
        redirect_to download_attachment_path(att)
      end
    }
  end

  def download_all
    secure{
      @fir = FileImportResult.find(params[:id])
      if @fir.change_records.length > 200
        @fir.delay.download_results(true, current_user.id, true)
        flash[:notices] = ["You will receive a system message when your file is finished processing."]
        redirect_to :back
      else
        att = @fir.download_results(true, current_user.id)
        redirect_to download_attachment_path(att)
      end
    }
  end

  private
  def secure &block
    fr = FileImportResult.find params[:id]
    imp_file = fr.imported_file
    action_secure(imp_file.can_view?(current_user),fr,{:lock_check=>false,:verb=>"view",:module_name=>"Log"}) {
      @imported_file = imp_file
      @file_import_result = fr
      yield
    }
  end

end

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

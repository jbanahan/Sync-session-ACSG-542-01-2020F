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
    secure{
      download_results(false)
    }
  end

  def download_all
    secure{
      download_results(true)
    }
  end

  def download_results(include_all)
    @fir = FileImportResult.find(params[:id])
    name = @fir.imported_file.try(:attached_file_name).nil? ? "File Import Results #{Time.now.to_date.to_s}.csv" : File.basename(@fir.imported_file.attached_file_name,File.extname(@fir.imported_file.attached_file_name)) + " - Results.csv" 
    f = File.new(name,"w+")
    f.write("Record Number,Status\r\n")
    @fir.change_records.each do |cr|
      next if ((!include_all) && (!cr.failed?))
      record_information = cr.record_sequence_number.to_s + ","
      record_information += cr.failed? ? "Error" : "Success"
      record_information += "\r\n"
      f.write(record_information)
    end
    send_file(f, type: "text/csv")
    f.close
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

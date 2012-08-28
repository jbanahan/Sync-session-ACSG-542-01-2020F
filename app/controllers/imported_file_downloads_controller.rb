class ImportedFileDownloadsController < ApplicationController
  def index
    f = ImportedFile.find params[:imported_file_id]
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"view",:module_name=>"uploaded file"}) {
      @f = f
    }
  end
  def show
    f = ImportedFile.find params[:imported_file_id]
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"view",:module_name=>"uploaded file"}) {
      df = f.imported_file_downloads.find_by_id(params[:id])
      if df.nil?
        add_flash :errors, "Downloaded file with id #{params[:id]} not found."
        redirect_to imported_file_imported_file_downloads_path(f)
      else
        send_data df.attachment_data, 
            :filename => df.attached_file_name,
            :type => df.attached_content_type,
            :disposition => 'attachment'  
      end
    }
  end
end

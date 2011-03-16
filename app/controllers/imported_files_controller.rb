require "net/https"
require "uri"

class ImportedFilesController < ApplicationController
  
  def new
    ss = SearchSetup.find(params[:search_setup_id])
    action_secure(ss.user==current_user,ss,{:lock_check=>false, :verb=>"upload",:module_name=>"search"}) {
      @search_setup = ss
      @imported_file = @search_setup.imported_files.build 
    }
  end

  def create
    ss = SearchSetup.find(params[:search_setup_id])
    action_secure(ss.user==current_user,ss,{:lock_check=>false,:verb=>"upload",:module_name=>"search"}) {
      @imported_file = ss.imported_files.build(params[:imported_file])
      if @imported_file.attached_file_name.nil?
        add_flash :errors, "You must select a file to upload."
        redirect_to request.referrer
      else
        if @imported_file.save
          redirect_to [ss,@imported_file]
        else
          errors_to_flash @imported_file
          redirect_to request.referrer
        end
      end
    }
  end
  
  def show
    ss = SearchSetup.find(params[:search_setup_id])
    action_secure(ss.user==current_user,ss,{:lock_check=>false,:verb=>"upload",:module_name=>"search"}) {
      @search_setup = ss
      @imported_file = ss.imported_files.where(:id=>params[:id]).first
    }
  end
  
  def download
    @imported_file = ImportedFile.find(params[:id])
    if @imported_file.nil?
      add_flash :errors, "File could not be found."
      redirect_to request.referrer
    else
      send_data @imported_file.attachment_data, 
          :filename => @imported_file.filename,
          :type => @imported_file.content_type,
          :disposition => 'attachment'  
    end
  end

  def process_file
    @imported_file = ImportedFile.find(params[:id])
    if @imported_file.process
      add_flash :notices, "File successfully processed."
      redirect_to :root
    else
      errors_to_flash @imported_file
      redirect_to request.referrer
    end
  end  
  
end

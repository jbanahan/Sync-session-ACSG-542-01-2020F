require "net/https"
require "uri"

class ImportedFilesController < ApplicationController
  
  def new
    @imported_file = ImportedFile.new
    @import_configs = ImportConfig.all
  end

  def create
    @imported_file = ImportedFile.new(params[:imported_file])
    if @imported_file.filename.nil?
      add_flash :errors, "You must select a file to upload."
      redirect_to request.referrer
    else
      set_content_type(@imported_file)
      if @imported_file.content_type && @imported_file.save
        redirect_to @imported_file
      else
        errors_to_flash @imported_file
        redirect_to request.referrer
      end
    end
  end
  
  def show
    @imported_file = ImportedFile.find(params[:id])
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
  
  private
  CONTENT_TYPE_MAP = {:csv => 'text/csv', :doc => 'application/msword', :docx => 'application/msword',
    :xls => 'application/vnd.ms-excel', :xlsx => 'application/vnd.ms-excel'}
  def set_content_type(f)
    if f.content_type.blank?
      ext = File.extname(f.filename)
      ct = CONTENT_TYPE_MAP[ext.starts_with?('.') ? ext[1,ext.length-1].downcase.intern : 'BAD'.intern]
      if ct.blank?
        add_flash :errors, "File '#{f.filename}' could not be identified."
      end
      f.content_type = ct
    end
  end
  
  
end
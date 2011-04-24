require "net/https"
require "uri"

class ImportedFilesController < ApplicationController
  
  def index
    @imported_files = ImportedFile.where(:user_id=>current_user.id).order("created_at DESC").paginate(:page=>20, :page=>params[:page])
  end

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
      @imported_file.module_type = ss.module_type
      @imported_file.user = current_user
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
    f = ImportedFile.find params[:id]
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"view",:module_name=>"uploaded file"}) {
      @imported_file = f
      s = @imported_file.search_runs.where(:user_id=>current_user.id).first
      s = @imported_file.search_runs.build(:user_id=>current_user.id) if s.nil?
      s.last_accessed = Time.now
      s.save
      @search_run = s
      @file_import_result = @imported_file.last_file_import_finished
      if @file_import_result      
        @target_page = params[:page].nil? ? 0 : params[:page].to_i
        changed_objs = @file_import_result.changed_objects
        @changed_objects = get_page changed_objs, @target_page, 20
        @max_pages = (changed_objs.size / 20)+1
      end
      idx = 0
      @columns = @imported_file.core_module.default_search_columns.collect {|c| 
        sc = SearchColumn.new(:model_field_uid=>c.to_s,:rank=>idx)
        idx += 1
        sc
      }
      @bulk_actions = f.core_module.bulk_actions current_user
    }
  end
  
  def download
    f = ImportedFile.find(params[:id])
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"download",:module_name=>"uploaded file"}) {
      @imported_file = f
      if @imported_file.nil?
        add_flash :errors, "File could not be found."
        redirect_to request.referrer
      else
        send_data @imported_file.attachment_data, 
            :filename => @imported_file.attached_file_name,
            :type => @imported_file.attached_content_type,
            :disposition => 'attachment'  
      end
    }
  end

  def process_file
    f = ImportedFile.find(params[:id])
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"process",:module_name=>"uploaded file"}) {
      @imported_file = f
      if @imported_file.process current_user
        add_flash :notices, "File successfully processed."
        redirect_to @imported_file 
      else
        errors_to_flash @imported_file
        redirect_to request.referrer
      end
    }
  end  
  
  def preview
    f = ImportedFile.find(params[:id])
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"view",:module_name=>"uploaded file"}) {
      respond_to do |format|
        format.json { render :json=>f.preview(current_user) }
        format.html { render :text=>"This page is not accessible for end users."}
      end
    }
  end

private
  #target_page is 0 based
  def get_page array, target_page, page_size
    a = array.slice (target_page*page_size), page_size
    a.nil? ? [] : a
  end
end

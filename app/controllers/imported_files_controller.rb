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
      @filters = @imported_file.search_criterions
      @file_import_result = @imported_file.last_file_import_finished
      page = params[:page]
      page = (s.position/20)+1 if !page && s.position
      @changed_objects = @file_import_result.changed_objects(@filters).paginate(:per_page=>20,:page => page) if @file_import_result
      idx = 0
      @columns = @imported_file.search_columns
      if @columns.blank?
        @columns = @imported_file.core_module.default_search_columns.collect {|c| 
          sc = SearchColumn.new(:model_field_uid=>c.to_s,:rank=>idx)
          idx += 1
          sc
        }
      end
      @bulk_actions = f.core_module.bulk_actions current_user
    }
  end

  # show the user prompt page for emailing the imported file
  def show_email_file
    f = ImportedFile.find params[:id]
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"email",:module_name=>"uploaded file"}) {
      @file = f
      # if the search has tariff record columns, then give the option to include extra countries
      include_extra_countries = false
      @file.search_columns.each do |sc|
        include_extra_countries = true if sc.model_field.core_module == CoreModule::TARIFF
      end
      @extra_countries = include_extra_countries ? Country.import_locations.sort_name : nil 
    }
  end

  # email the updated current data for an imported_file
  def email_file
    f = ImportedFile.find params[:id]
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"email",:module_name=>"uploaded file"}) {
      if params[:to].blank?
        error_redirect "You must include a \"To\" address." 
        return
      end
      subject = params[:subject].blank? ? "[chain.io] #{@file.core_module.label} data." : params[:subject]
      body = params[:body].blank? ? "#{current_user.full_name} has sent you the attached file from chain.io." : params[:body]
      opts = {}
      opts[:extra_country_ids] = params[:extra_countries] unless params[:extra_countries].blank?
      f.delay.email_updated_file current_user, params[:to], "", subject, body, opts
      add_flash :notices, "The file will be processed and sent shortly."
      redirect_to f
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

  def filter
    f = ImportedFile.find params[:id]
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"filter",:module_name=>"uploaded file"}) {
      search_params = (params[:imported_file] && params[:imported_file][:search_criterions_attributes]) ? params[:imported_file][:search_criterions_attributes] : {}
      f.search_criterions.destroy_all
      search_params.each do |k,p|
        p.delete "_destroy"
        f.search_criterions.create(p)
      end
      redirect_to f
    }
  end

  def download_items
    f = ImportedFile.find(params[:id])
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"download",:module_name=>"uploaded file"}) {
      criterions = []
      #is there a filter?
      if params[:search_setup]
        #right now the UI only allows one filter, but this loop future proofs it
        params[:search_setup]['search_criterions_attributes'].values.each do |sc_hash|
          criterions << SearchCriterion.new(sc_hash) 
        end
      end
      if f.nil?
        error_redirect "File could not be found."
      elsif f.last_file_import_finished.nil?
        error_redirect "No results available.  This file has not been processed yet."
      else
        if params[:send_to]=='email' && !params[:email_to].blank?
          f.delay.email_items_file current_user, params[:email_to], criterions
          add_flash :notices, "The file will be sent to #{params[:email_to]}"
          redirect_to f
        else
          send_data f.make_items_file(criterions), :filename => f.attached_file_name, :type=>f.attached_content_type, :disposition=>'attachment'
        end
      end
    }
  end

  def process_file
    f = ImportedFile.find(params[:id])
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"process",:module_name=>"uploaded file"}) {
      f.process current_user, {:defer=>true}
      add_flash :notices, "Your file is being processed.  You will receive a message when it has completed."
      if f.search_setup
        redirect_by_core_module(f.search_setup.core_module,true)
      else
        redirect_to root_path
      end
    }
  end  
  
  def preview
    f = ImportedFile.find(params[:id])
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"view",:module_name=>"uploaded file"}) {
      respond_to do |format|
        format.json { 
          begin
            render :json=>f.preview(current_user) 
          rescue
            $!.log_me ["Imported File Preview Failed","Imported File ID: #{f.id}","Rails Root: #{Rails.root.to_s}","Username: #{current_user.username}"]
            render :json=>{:error=>true}
          end
        }
        format.html { render :text=>"This page is not accessible for end users."}
      end
    }
  end

  def destroy
    f = ImportedFile.find(params[:id])
    action_secure(f.can_delete?(current_user),f,{:lock_check=>false,:verb=>"delete",:module_name=>"uploaded file"}) {
      if f.file_import_results.blank?
        f.destroy
        add_flash :notices, "File successfully deleted."
        redirect_to imported_files_path
      else
        error_redirect "You cannot delete an upload that has already been processed."
      end
    }
  end

end

require "net/https"
require "uri"
require 'open_chain/search_query_controller_helper'

class ImportedFilesController < ApplicationController
  include OpenChain::SearchQueryControllerHelper

  def legacy_javascripts?
    false
  end
  
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
  
  def show_angular
    @no_action_bar = true #implements it's own via templates/search_results.html
  end

  def show
    respond_to do |format|
      format.html {
        redirect_to "/imported_files/show_angular#/#{params[:id]}"
      }
      format.json {
        f = ImportedFile.find params[:id]
        fir= f.last_file_import_finished
        raise ActionController::RoutingError.new('Not Found') unless f.can_view?(current_user)
        r = {:id=>f.id,
          :file_name=>f.attached_file_name,
          :show_email_button=>(f.attached_file_name && (f.attached_file_name.downcase.ends_with?(".xls") || f.attached_file_name.downcase.ends_with?(".xlsx"))),
          :uploaded_at=>f.created_at.strftime("%Y-%m-%d %H:%M"),
          :uploaded_by=>f.user.full_name,
          :never_processed=>fir.nil?,
          :total_rows=>(fir ? fir.change_records.size : ''),
          :total_records=>f.result_keys.count,
          :last_processed=>(fir && fir.finished_at ? fir.finished_at.strftime("%Y-%m-%d %H:%M") : ''),
          :time_to_process=>(fir ? fir.time_to_process : ''),
          :processing_error_count=>(fir ? fir.error_count : ''),
          :current_user=>{'id'=>current_user.id,'full_name'=>current_user.full_name,'email'=>current_user.email},
          :search_criterions=>f.search_criterions.collect {|c| {:mfid=>c.model_field_uid,:label=>c.model_field.label,:operator=>c.operator,:value=>c.value,:datatype=>c.model_field.data_type,:include_empty=>c.include_empty?}},
          :model_fields => ModelField.sort_by_label(f.core_module.model_fields_including_children(current_user).values).collect {|mf| {:mfid=>mf.uid,:label=>mf.label,:datatype=>mf.data_type}},
          :file_import_result => {}
        } 
        r[:file_import_result][:id] = fir.id if fir
        r[:available_countries] = Country.import_locations.sort_classification_rank.collect {|c| {:id=>c.id,:iso_code=>c.iso_code,:name=>c.name}}
        render :json=>r
      }
    end
  end
  
  def results
    f = ImportedFile.find params[:id]
    raise ActionController::RoutingError.new('Not Found') unless f.can_view?(current_user)
    page = number_from_param params[:page], 1
    # Only show 10 results per page for older IE versions.  This is because these browser
    # versions don't have the rendering speed of newer ones and take too long to load for 100
    # rows (plus, we want to encourage people to upgrade).
    per_page = (old_ie_version? ? 10 : 100)

    sr = f.search_runs.where(:user_id=>current_user.id).first 
    sr = f.search_runs.build unless sr
    sr.last_accessed=Time.now
    sr.page = page
    sr.per_page = per_page
    sr.save!
    def f.name; self.attached_file_name; end #duck typing to search setup
    query_hash = execute_query_to_hash(SearchQuery.new(f,current_user,:extra_from=>f.result_keys_from),current_user,page,per_page) 
    query_hash[:search_run_id] = sr.id
    render json: query_hash
  end

  # email the updated current data for an imported_file
  def email_file
    f = ImportedFile.find params[:id]
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"email",:module_name=>"uploaded file"}) {
      if params[:to].blank?
        error_redirect "You must include a \"To\" address." 
        return
      end
      subject = params[:subject].blank? ? "[VFI Track] #{@file.core_module.label} data." : params[:subject]
      body = params[:body].blank? ? "#{current_user.full_name} has sent you the attached file from VFI Track." : params[:body]
      opts = {}
      opts[:extra_country_ids] = params[:extra_countries] unless params[:extra_countries].blank?
      f.delay.email_updated_file current_user, params[:to], "", subject, body, opts
      add_flash :notices, "The file will be processed and sent shortly."
      respond_to do |format|
        format.html {redirect_to f}
        format.json {render :json=>{:ok=>:ok}}
      end
    }
  end
  
  def download
    f = ImportedFile.find(params[:id])
    action_secure(f.can_view?(current_user),f,{:lock_check=>false,:verb=>"download",:module_name=>"uploaded file"}) {
      @imported_file = f
      respond_to do |format|
        format.html {
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
        format.json {
          cookies[:fileDownload] = {:value=>'true', :path=>'/'} #jQuery support http://johnculviner.com/post/2012/03/22/Ajax-like-feature-rich-file-downloads-with-jQuery-File-Download.aspx
          send_data @imported_file.attachment_data, 
              :filename => @imported_file.attached_file_name,
              :type => @imported_file.attached_content_type,
              :disposition => 'attachment'  
        }
      end
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
            render :json=>{:error=>$!.message}
          end
        }
        format.html { render :text=>"This page is not accessible for end users."}
      end
    }
  end

  def update_search_criterions
    f = ImportedFile.find(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless f.can_view?(current_user)
    f.search_criterions.delete_all
    criterion_params = params[:imported_file][:search_criterions]
    unless criterion_params.blank?
      criterion_params.each do |cp|
        f.search_criterions.build(:model_field_uid=>cp[:mfid],:operator=>cp[:operator],:value=>cp[:value],:include_empty=>cp[:include_empty])
      end
      f.save!
    end
    render :json=>{:ok=>:ok}
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

require 'open_chain/search_query_controller_helper'
class AdvancedSearchController < ApplicationController
  include OpenChain::SearchQueryControllerHelper

  def legacy_javascripts?
    false
  end

  def index
    render :layout=>'one_col'
  end
 
  def update
    ss = SearchSetup.for_user(current_user).find_by_id(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless ss
    base_params = params[:search_setup]
    SearchSetup.transaction do
      ss.name = base_params[:name] unless base_params[:name].blank?
      ss.include_links = base_params[:include_links]
      ss.no_time = base_params[:no_time]
      
      ss.search_columns.delete_all
      unless base_params[:search_columns].blank?
        base_params[:search_columns].each do |sc|
          col = ss.search_columns.build :model_field_uid=>sc[:mfid], :rank=>sc[:rank]
          col.model_field_uid = "_blank" if col.model_field_uid.match /^_blank/
        end
      end

      ss.sort_criterions.delete_all
      unless base_params[:sort_criterions].blank?
        base_params[:sort_criterions].each do |sc|
          ss.sort_criterions.build :model_field_uid=>sc[:mfid], :rank=>sc[:rank], :descending=>sc[:descending]
        end
      end

      ss.search_schedules.delete_all
      unless base_params[:search_schedules].blank?
        base_params[:search_schedules].each do |sc|
          sched = ss.search_schedules.build :email_addresses=>sc[:email_addresses], 
            :run_hour=>sc[:run_hour], :day_of_month=>sc[:day_of_month], :download_format=>sc[:download_format],
            :run_monday=>sc[:run_monday],
            :run_tuesday=>sc[:run_tuesday],
            :run_wednesday=>sc[:run_wednesday],
            :run_thursday=>sc[:run_thursday],
            :run_friday=>sc[:run_friday],
            :run_saturday=>sc[:run_saturday],
            :run_sunday=>sc[:run_sunday]
          if ss.can_ftp?
            sched.ftp_server = sc[:ftp_server]
            sched.ftp_username = sc[:ftp_username]
            sched.ftp_password = sc[:ftp_password]
            sched.ftp_subfolder = sc[:ftp_subfolder]
          end
        end
      end
      
      ss.search_criterions.delete_all
      unless base_params[:search_criterions].blank?
        base_params[:search_criterions].each do |sc|
          ss.search_criterions.build :model_field_uid=>sc[:mfid], :operator=>sc[:operator], :value=>sc[:value], :include_empty=>sc[:include_empty]
        end
      end

      ss.save!
    end
    render :json=>{:ok=>:ok}
  end
  def show

    respond_to do |format|
      format.html {redirect_to "/advanced_search#/#{params[:id]}"}
      format.json {
        page = number_from_param params[:page], 1
        # Only show 10 results per page for older IE versions.  This is because these browser
        # versions don't have the rendering speed of newer ones and take too long to load for 100
        # rows (plus, we want to encourage people to upgrade).
        per_page = (old_ie_version? ? 10 : 100)

        ss = SearchSetup.for_user(current_user).find_by_id(params[:id]) 
        raise ActionController::RoutingError.new('Not Found') unless ss
        ss.touch
        sr = ss.search_runs.first
        sr = ss.search_runs.create! unless sr
        sr.page = page
        sr.per_page = per_page
        sr.last_accessed = Time.now
        sr.save!

        h = execute_query_to_hash(SearchQuery.new(ss,current_user),current_user,page,per_page)
        h[:search_run_id] = sr.id
        render :json=> h
      }
    end
  end

  def download
    ss = SearchSetup.for_user(current_user).find_by_id(params[:id]) 
    raise ActionController::RoutingError.new('Not Found') unless ss
    respond_to do |format|
      format.xls {
        m = XlsMaker.new(:include_links=>ss.include_links?,:no_time=>ss.no_time?)
        sq = SearchQuery.new ss, current_user
        book = m.make_from_search_query sq
        spreadsheet = StringIO.new 
        book.write spreadsheet 
        send_data spreadsheet.string, :filename => "#{ss.name}.xls", :type =>  "application/vnd.ms-excel"
      }
      format.json {
        ReportResult.run_report! ss.name, current_user, 'OpenChain::Report::XLSSearch', :settings=>{ 'search_setup_id'=>ss.id }
        render :json=>{:ok=>:ok}
      }
    end
  end

  def last_search_id
    setup = current_user.search_setups.includes(:search_runs).order("search_runs.updated_at DESC").limit(1).first
    setup = current_user.search_setups.order("updated_at DESC").limit(1).first if setup.nil?
    render :json=>{:id=>(setup ? setup.id.to_s : "0")}
  end

  def setup
    respond_to do |format|
      format.html {redirect_to "/advanced_search#/#{params[:id]}"}
      format.json {
        ss = current_user.search_setups.find_by_id params[:id]
        raise ActionController::RoutingError.new('Not Found') unless ss
        h = {
          :id=>ss.id,
          :module_type=>ss.module_type,
          :name=>ss.name,
          :include_links=>ss.include_links?,
          :no_time=>ss.no_time?,
          :allow_ftp=>ss.can_ftp?,
          :user=>{:email=>ss.user.email},
          :uploadable_error_messages=>ss.uploadable_error_messages,
          :search_list=>current_user.search_setups.where(:module_type=>ss.module_type).order(:name).collect {|s| {:name=>s.name,:id=>s.id,:module=>s.core_module.label}},
          :search_columns=>ss.search_columns.collect {|c| {:mfid=>c.model_field_uid,:label=>c.model_field.label,:rank=>c.rank}},
          :sort_criterions=>ss.sort_criterions.collect {|c| {:mfid=>c.model_field_uid,:label=>c.model_field.label,:rank=>c.rank,:descending=>c.descending?}},
          :search_criterions=>ss.search_criterions.collect {|c| {:mfid=>c.model_field_uid,:label=>c.model_field.label,:operator=>c.operator,:value=>c.value,:datatype=>c.model_field.data_type,:include_empty=>c.include_empty?}},
          :search_schedules=>ss.search_schedules.collect {|s|
            {:email_addresses=>s.email_addresses, :run_monday=>s.run_monday?, :run_tuesday=>s.run_tuesday?, :run_wednesday=>s.run_wednesday?, :run_thursday=> s.run_thursday?, :run_friday=>s.run_friday?,
            :run_saturday=>s.run_saturday?, :run_sunday=>s.run_sunday?, :run_hour=>s.run_hour, :day_of_month=> s.day_of_month, :download_format=>s.download_format}
          },
          :model_fields => ModelField.sort_by_label(ss.core_module.model_fields_including_children(current_user).values).collect {|mf| {:mfid=>mf.uid,:label=>mf.label,:datatype=>mf.data_type}}
        }
        render :json=>h
      }
    end
  end

  def create
    m = params[:module_type]
    raise ActionController::RoutingError.new('Not found for empty module type') if m.blank?
    cm = CoreModule.find_by_class_name m
    raise ActionController::RoutingError.new('Not Found') unless cm.view?(current_user)
    ss = cm.make_default_search current_user
    ss.name = "New Search"
    ss.save
    render :json=>{:id=>ss.id}
  end

  def destroy
    id = params[:id]
    ss = current_user.search_setups.find_by_id(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless ss
    ss.destroy
    previous_search = current_user.search_setups.for_module(ss.core_module).order("updated_at DESC").limit(1).first
    previous_search = ss.core_module.make_default_search(current_user) unless previous_search
    render :json=>{:id=>previous_search.id}
  end

end

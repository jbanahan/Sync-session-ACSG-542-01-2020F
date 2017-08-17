require 'open_chain/search_query_controller_helper'
require 'open_chain/report/xls_search'
require 'open_chain/email_validation_support'

class AdvancedSearchController < ApplicationController
  include OpenChain::SearchQueryControllerHelper
  include OpenChain::EmailValidationSupport

  def legacy_javascripts?
    false
  end

  def index
    @no_action_bar = true #implements it's own via templates/search_results.html
  end
 
  def update
    ss = SearchSetup.for_user(current_user).find_by_id(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless ss
    base_params = params[:search_setup]
    
    if base_params[:search_criterions].blank?
      if base_params[:sort_criterions].presence || base_params[:search_schedules].presence
        render_json_error "Must have a search criterion to include sorts or schedules!"
        return
      end
    end

    if base_params[:search_schedules] && base_params[:search_schedules].map { |sc| sc[:email_addresses].length > 255 if sc[:email_addresses]}.any?  
      render_json_error "Email address field must be no more than 255 characters!"
      return
    end

    SearchSetup.transaction do
      ss.name = base_params[:name] unless base_params[:name].blank?
      ss.include_links = base_params[:include_links]
      ss.no_time = base_params[:no_time]
      ss.search_columns.delete_all
      user = current_user
      unless base_params[:search_columns].blank?
        base_params[:search_columns].each do |sc|
          next unless ModelField.find_by_uid(sc[:mfid]).user_accessible?
          col = ss.search_columns.build :model_field_uid=>sc[:mfid], :rank=>sc[:rank]
          col.model_field_uid = "_blank" if col.model_field_uid.match /^_blank/
        end
      end

      ss.sort_criterions.delete_all
      unless base_params[:sort_criterions].blank?
        base_params[:sort_criterions].each do |sc|
          next unless ModelField.find_by_uid(sc[:mfid]).user_accessible?
          ss.sort_criterions.build :model_field_uid=>sc[:mfid], :rank=>sc[:rank], :descending=>sc[:descending]
        end
      end

      ss.search_schedules.delete_all
      unless base_params[:search_schedules].blank?
        base_params[:search_schedules].each do |sc|
          sched = ss.search_schedules.build :email_addresses=>sc[:email_addresses], :send_if_empty=>sc[:send_if_empty],
            :run_hour=>sc[:run_hour], :day_of_month=>sc[:day_of_month], :download_format=>sc[:download_format], :exclude_file_timestamp=>sc[:exclude_file_timestamp],
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
            sched.protocol = sc[:protocol]
          end
        end
      end
      
      ss.search_criterions.delete_all
      unless base_params[:search_criterions].blank?
        base_params[:search_criterions].each do |sc|
          next unless ModelField.find_by_uid(sc[:mfid]).user_accessible?
          ss.search_criterions.build :model_field_uid=>sc[:mfid], :operator=>sc[:operator], :value=>sc[:value], :include_empty=>sc[:include_empty]
        end
      end

      ss.save!
    end
    render :json=>{:ok=>:ok}
  end
  def show
    respond_to do |format|
      format.html {
        redirect_to "/advanced_search#/#{params[:id]}/1"
      }
      format.json {
        page = number_from_param params[:page], 1
        per_page = results_per_page        

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

        #load the result cached in another thread so it doesn't block
        sr_id = sr.id #only reference the id so we get a clean object from the database to avoid threading conflicts
        Thread.new do
          #need to wrap connection handling for safe threading per: http://bibwild.wordpress.com/2011/11/14/multi-threading-in-rails-activerecord-3-0-3-1/
          ActiveRecord::Base.connection_pool.with_connection do
            s_run = SearchRun.find sr_id
            rc = s_run.parent.result_cache
            if rc
              rc.update_attributes(object_ids:nil,page:s_run.page,per_page:s_run.per_page)
              rc.load_current_page
            end
          end

        end
      }
    end
  end

  def total_objects
    ss = SearchSetup.for_user(current_user).find_by_id(params[:id]) 
    raise ActionController::RoutingError.new('Not Found') unless ss
    render :json=>total_object_count_hash(SearchQuery.new(ss,current_user))
  end

  def download
    ss = SearchSetup.for_user(current_user).find_by_id(params[:id]) 
    raise ActionController::RoutingError.new('Not Found') unless ss
    respond_to do |format|
      format.xls {
        # Don't worry about checking for search criterions, since the only time this is supposed
        # to be called when the results are limited to a single page.  
        m = XlsMaker.new(:include_links=>ss.include_links?,:no_time=>ss.no_time?)
        sq = SearchQuery.new ss, current_user
        # Make sure the we enforce limiting results to a single page.
        wb, length = *m.make_from_search_query(sq, per_page: results_per_page, single_page: true)
        send_excel_workbook wb, "#{ss.name}.xls"
      }
      format.json {
        errors = []
        if ss.downloadable? errors
          ReportResult.run_report! ss.name, current_user, 'OpenChain::Report::XLSSearch', :settings=>{ 'search_setup_id'=>ss.id }
          render :json=>{:ok=>:ok}
        else
          render json: {:errors => errors}, status: 500
        end
      }
    end
  end

  def send_email
    ss = SearchSetup.for_user(current_user).find_by_id(params[:id]) 
    raise ActionController::RoutingError.new('Not Found') unless ss
    errors = []
    if ss.downloadable? errors
      mail_fields = params[:mail_fields] || {}
      email_to = mail_fields[:to]
      if email_to.blank?
        render_json_error "Please enter an email address."
      else
        email_list = email_to.split(',')
        if email_list.count > 10
          render_json_error "Cannot accept more than 10 email addresses."
        else
          if !email_list_valid? email_list
            render_json_error "Please ensure all email addresses are valid and separated by commas."
          else
            OpenChain::Report::XLSSearch.delay.run_and_email_report current_user, ss.id, mail_fields
            render :json=>{:ok=>:ok}
          end
        end
      end
    else
      render_json_error errors.first
    end
  end

  def last_search_id
    setup = current_user.search_setups.joins(:search_runs).order("search_runs.updated_at DESC").limit(1).first
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
          :allow_template=>current_user.admin?,
          :user=>{:email=>ss.user.email},
          :uploadable_error_messages=>ss.uploadable_error_messages,
          :search_list=>current_user.search_setups.where(:module_type=>ss.module_type).order(:name).collect {|s| {:name=>s.name,:id=>s.id,:module=>s.core_module.label}},
          :search_columns=>ss.search_columns.collect {|c| {:mfid=>c.model_field_uid,:label=>(c.model_field.can_view?(current_user) ? c.model_field.label : ModelField.disabled_label),:rank=>c.rank}},
          :sort_criterions=>ss.sort_criterions.collect {|c| {:mfid=>c.model_field_uid,:label=>(c.model_field.can_view?(current_user) ? c.model_field.label : ModelField.disabled_label),:rank=>c.rank,:descending=>c.descending?}},
          :search_criterions=>ss.search_criterions.collect {|c| c.json(current_user)},
          :search_schedules=>ss.search_schedules.collect {|s|
            f = {:email_addresses=>s.email_addresses, :send_if_empty=>s.send_if_empty, :run_monday=>s.run_monday?, :run_tuesday=>s.run_tuesday?, :run_wednesday=>s.run_wednesday?, :run_thursday=> s.run_thursday?, :run_friday=>s.run_friday?,
            :run_saturday=>s.run_saturday?, :run_sunday=>s.run_sunday?, :run_hour=>s.run_hour, :day_of_month=> s.day_of_month, :download_format=>s.download_format, :exclude_file_timestamp=>s.exclude_file_timestamp}

            if ss.can_ftp?
              f[:ftp_server] = s.ftp_server
              f[:ftp_username] = s.ftp_username
              f[:ftp_password] = s.ftp_password
              f[:ftp_subfolder] = s.ftp_subfolder
              f[:protocol] = s.protocol
            end
            f
          },
          :model_fields => ModelField.sort_by_label(get_model_fields_for_setup(ss)).collect {|mf| {:mfid=>mf.uid,:label=>mf.label,:datatype=>mf.data_type}}
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

  private
    def results_per_page
      # Only show 10 results per page for older IE versions.  This is because these browser
      # versions don't have the rendering speed of newer ones and take too long to load for 100
      # rows (plus, we want to encourage people to upgrade).
      per_page = (old_ie_version? ? 10 : 100)

      # Some search implementations may specify a per page value via the params, allow it 
      # as long as the value isn't more than our predefined value.
      query_per_page = number_from_param params[:per_page], nil

      if query_per_page && (query_per_page < per_page)
        per_page = query_per_page
      end

      per_page
    end

    def get_model_fields_for_setup search_setup
      chain = search_setup.core_module.default_module_chain
      chain.model_fields(current_user).values
    end
end

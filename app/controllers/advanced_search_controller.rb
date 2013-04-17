class AdvancedSearchController < ApplicationController
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
          ss.search_criterions.build :model_field_uid=>sc[:mfid], :operator=>sc[:operator], :value=>sc[:value]
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
        ss = SearchSetup.for_user(current_user).find_by_id(params[:id]) 
        raise ActionController::RoutingError.new('Not Found') unless ss
        ss.touch

        p_str = params[:page]
        page = 1
        page = p_str.to_i if !p_str.blank? && p_str.match(/^[1-9][0-9]*$/)

        per_str = params[:per_page]
        per_page = 100
        per_page = per_str.to_i if !per_str.blank? && per_str.match(/^[1-9][0-9]*$/)
        
        sq = SearchQuery.new ss, current_user

        #figure out page count
        row_count = sq.count
        total_pages = row_count/per_page
        total_pages += 1 if row_count % per_page > 0

        cols = ss.search_columns.order(:rank=>:asc).collect {|col| ModelField.find_by_uid(col.model_field_uid).label} 

        k = ss.core_module.klass
        rows = []
        no_edit_links = false
        sq.execute(:per_page=>per_page,:page=>page) do |row|
          obj = k.find row[:row_key]
          links = []
          view_path = polymorphic_path(obj)
          links << {'label'=>'View', 'url'=>view_path} if obj.can_view?(current_user)
          unless no_edit_links
            begin
              ep = "edit_#{obj.class.to_s.underscore}_path"
              edit_path = "#{view_path}/edit"
              links << {'label'=>'Edit', 'url'=>edit_path} if !no_edit_links && obj.respond_to?(:can_edit?) && obj.can_edit?(current_user) && self.respond_to?(ep)
            rescue ActionController::RoutingError
              no_edit_links = true
            end
          end
          
          #format dates & times
          tz = ActiveSupport::TimeZone[current_user.time_zone ? current_user.time_zone : 'Eastern Time (US & Canada)']
          row[:result].each_with_index do |r,i|
            if r.respond_to?(:acts_like_time?) && r.acts_like_time?
              row[:result][i] = ss.no_time? ? r.strftime("%Y-%m-%d") : tz.at(r).to_s
            elsif r.respond_to?(:acts_like_date?) && r.acts_like_date?
              row[:result][i] = r.strftime("%Y-%m-%d")
            end
          end

          rows << {'id'=>obj.id, 'links'=>links, 'vals'=>row[:result]}
        end
        sr = ss.search_run
        sr = ss.build_search_run unless sr
        sr.page = page
        sr.per_page = per_page
        sr.save!
        render :json=>{
          :name=>ss.name,
          :search_run_id=>ss.search_run.id,
          :page=>page,
          :id=>ss.id,
          :columns=>cols,
          :rows=>rows,
          :total_pages=>total_pages,
          :total_objects=>sq.unique_parent_count,
          :bulk_actions=>prep_bulk_actions(ss.core_module)
        }
      }
    end
  end

  def last_search_id
    setup = current_user.search_setups.includes(:search_run).order("search_runs.updated_at DESC").limit(1).first
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
          :search_list=>current_user.search_setups.where(:module_type=>ss.module_type).order(:name).collect {|s| {:name=>s.name,:id=>s.id,:module=>s.core_module.label}},
          :search_columns=>ss.search_columns.collect {|c| {:mfid=>c.model_field_uid,:label=>c.model_field.label,:rank=>c.rank}},
          :sort_criterions=>ss.sort_criterions.collect {|c| {:mfid=>c.model_field_uid,:label=>c.model_field.label,:rank=>c.rank,:descending=>c.descending?}},
          :search_criterions=>ss.search_criterions.collect {|c| {:mfid=>c.model_field_uid,:label=>c.model_field.label,:operator=>c.operator,:value=>c.value,:datatype=>c.model_field.data_type}},
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
    cm = CoreModule.find_by_class_name m
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
  def prep_bulk_actions core_module
    bulk_actions = []
    core_module.bulk_actions(current_user).each do |k,v|
      h = {"label"=>k.to_s}
      if v.is_a? String
        h["path"] = eval(v) 
      else
        h["path"] = v[:path]
        h["callback"] = v[:ajax_callback]
      end
      bulk_actions << h
    end
    bulk_actions
  end
end

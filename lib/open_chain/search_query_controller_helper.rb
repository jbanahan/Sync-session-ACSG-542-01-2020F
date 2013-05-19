module OpenChain
  module SearchQueryControllerHelper
    def execute_query_to_hash sq, user, page, per_page
      
      ss = sq.search_setup

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
        links << {'label'=>'View', 'url'=>view_path} if obj.can_view?(user)
        unless no_edit_links
          begin
            ep = "edit_#{obj.class.to_s.underscore}_path"
            edit_path = "#{view_path}/edit"
            links << {'label'=>'Edit', 'url'=>edit_path} if !no_edit_links && obj.respond_to?(:can_edit?) && obj.can_edit?(user) && self.respond_to?(ep)
          rescue ActionController::RoutingError
            no_edit_links = true
          end
        end
        
        #format dates & times
        tz = ActiveSupport::TimeZone[user.time_zone ? user.time_zone : 'Eastern Time (US & Canada)']
        row[:result].each_with_index do |r,i|
          if r.respond_to?(:acts_like_time?) && r.acts_like_time?
            row[:result][i] = ss.no_time? ? r.strftime("%Y-%m-%d") : tz.at(r).to_s
          elsif r.respond_to?(:acts_like_date?) && r.acts_like_date?
            row[:result][i] = r.strftime("%Y-%m-%d")
          end
        end

        rows << {'id'=>obj.id, 'links'=>links, 'vals'=>row[:result]}
      end
      h = {
          :name=>ss.name,
          :page=>page,
          :id=>ss.id,
          :columns=>cols,
          :rows=>rows,
          :total_pages=>total_pages,
          :total_objects=>sq.unique_parent_count,
          :core_module_name=>ss.core_module.label,
          :bulk_actions=>prep_bulk_actions(ss.core_module,user)
        }

      h[:search_run_id]=ss.search_run.id if ss.respond_to?(:search_run) && ss.search_run
      h
    end
    def number_from_param param, default
      r = default
      r = param.to_i if !param.blank? && param.match(/^[1-9][0-9]*$/)
      r
    end
    def prep_bulk_actions core_module, user
      bulk_actions = []
      core_module.bulk_actions(user).each do |k,v|
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
end

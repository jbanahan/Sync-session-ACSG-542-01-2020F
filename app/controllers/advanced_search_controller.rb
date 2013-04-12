class AdvancedSearchController < ApplicationController
  def index
    render :layout=>'one_col'
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
          rows << {'id'=>obj.id, 'links'=>links, 'vals'=>row[:result]}
        end

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

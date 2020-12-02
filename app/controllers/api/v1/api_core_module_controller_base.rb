require 'api/v1/state_toggle_support'
require 'open_chain/api/v1/api_json_http_context'
require 'open_chain/api/v1/api_model_field_support'

# Concrete implementations should implement
# - core_module
# - json_generator (or directly implement/override obj_to_json_hash)
# - save_object
# And may implement
# - max_per_page
module Api; module V1; class ApiCoreModuleControllerBase < Api::V1::ApiController
  include Api::V1::StateToggleSupport
  include OpenChain::Api::V1::ApiModelFieldSupport

  prepend_before_action :allow_csv, only: [:index]

  def output_generator
    @g ||= begin
      g = json_generator
      g.json_context = OpenChain::Api::V1::ApiJsonHttpContext.new(params: params, user: current_user)
      g
    end
  end

  def obj_to_json_hash obj
    output_generator.obj_to_json_hash obj
  end

  def index
    render_search core_module
  end

  def show
    render_show core_module
  end

  def create
    do_create core_module
  end

  def update
    do_update core_module
  end

  # The param key to expect the actual object data to be posted into .ie params[:product] -> :product = object_param_name
  def object_param_name
    core_module.class_name.underscore
  end

  # Shortcut for params[object_param_name]
  def object_params
    params[object_param_name]
  end

  def render_show core_module
    obj = find_object_by_id params[:id]
    render_obj obj
  end

  # override this to implement custom finder
  def find_object_by_id id
    core_module.klass.find_by_id id
  end

  def render_obj obj
    # In general, use this method after you've preloaded the object you're rendering..it's good for
    # times when you're providing direct finder type methods (ala products/by_uid?uid="123")
    raise ActiveRecord::RecordNotFound unless obj && obj.can_view?(current_user)
    render json:{object_param_name => obj_to_json_hash(obj)}
  end

  # generic create method
  # subclasses must implement the save_object method which takes a hash and should return the object that was saved with any errors set
  def do_create core_module
    ActiveRecord::Base.transaction do
      obj_hash = object_params
      obj = save_object obj_hash
      obj.update_attributes(last_updated_by: current_user) if obj.respond_to?(:last_updated_by)
      if obj.errors.full_messages.blank?
        obj.create_async_snapshot if obj.respond_to?('create_async_snapshot')
      else
        raise StatusableError.new(obj.errors.full_messages, 400)
      end

      # call the equivalent of do_render instead of using the in memory object so we can benefit from any special optimizations that the implementing classes may do
      render_obj(find_object_by_id(obj.id))
    end
  end

  # generic update method
  # subclasses must implement the save_object method which takes a hash and should return the object that was saved with any errors set
  def do_update core_module
    ActiveRecord::Base.transaction do
      obj_hash = object_params
      raise StatusableError.new("Path ID #{params[:id]} does not match JSON ID #{obj_hash['id']}.", 400) unless params[:id].to_s == obj_hash['id'].to_s
      obj = save_object obj_hash
      obj.update_attributes(last_updated_by: current_user) if obj.respond_to?(:last_updated_by)
      if obj.errors.full_messages.blank?
        obj.create_async_snapshot if obj.respond_to?('create_async_snapshot')
      else
        raise StatusableError.new(obj.errors.full_messages, 400)
      end
      # call do_render instead of using the in memory object so we can benefit from any special optimizations that the implementing classes may do
      render_show core_module
    end
  end

  # load data into object via model fields
  # This method should be avoided unless for some reason you cannot use
  # update_model_field_attributes on your core_object
  def import_fields base_hash, obj, core_module
    # We want to allow access even to fields that aren't user)accessible via the search here for scenarios
    # where we're setting id values via autocomplete boxes (ports, address ids, etc)
    fields = core_module.every_model_field {|mf| !mf.read_only? && base_hash.has_key?(mf.uid.to_s) }
    user = current_user
    fields.each_pair do |uid, mf|
      uid = mf.uid.to_s
      # process_import handles checking if user can edit, so don't bother w/ that here
      mf.process_import(obj, base_hash[uid], user)
    end
    nil
  end

  # Simple implementation of a save_object method, which is called by do_create and do_update
  def generic_save_object obj_hash
    # For any simple enough object structure that only grants access to the data found in the
    # base object's CoreModule heirarchy, this method should be find to reference directly
    # as your sole piece of code when implementing "save_object"
    cm = core_module

    if obj_hash['id'].blank?
      obj = cm.new_object
    else
      obj = find_object_by_id obj_hash['id']
    end

    unless obj
      raise StatusableError.new("#{cm.label} Not Found" , 404)
    else
      generic_save_existing_object obj, obj_hash
    end

    obj
  end

  # save an object that you already have in memory
  def generic_save_existing_object obj, obj_hash
    cm = core_module
    # Preload the custom values for the object, but don't freeze them....if we freeze them before saving, then the snapshot that's done
    # later potentially won't store off some of the custom values
    CoreModule.walk_object_heirarchy(obj) {|core_mod, o| o.custom_values.to_a if o.respond_to?(:custom_values)}
    if obj.update_model_field_attributes obj_hash
      raise StatusableError.new("You do not have permission to save this #{cm.label}.", :forbidden) unless obj.can_edit?(current_user)
      obj.update_attributes(last_updated_by: current_user) if obj.respond_to?(:last_updated_by)

      # Now we can freeze the model fields, since all the possible new data should be loaded now.
      # Freezing at this point makes the snapshot run faster, and any actual data load that's done following the save
      obj.freeze_all_custom_values_including_children
    end
  end

  def render_search core_module
    user = current_user
    raise StatusableError.new("You do not have permission to view this module.", 401) unless user.view_module?(core_module)
    k = core_module.klass.all.select("DISTINCT #{core_module.table_name}.id")

    # apply search criterions
    search_criterions.each do |sc|
      return unless validate_model_field 'Search', sc.model_field_uid, core_module, user
      k = sc.apply(k)
    end

    k = core_module.klass.search_secure(user, k)
    if(params['count_only'])
      render json:{record_count:k.count}
    else
      outer_query = core_module.klass.where("ID IN (#{k.to_sql})")
      # apply sort criterions
      sort_criterions.each do |sc|
        return unless validate_model_field 'Sort', sc.model_field_uid, core_module, user
        outer_query = outer_query.order("#{sc.model_field.qualified_field_name}#{sc.descending? ? ' desc' : ''}")
      end
      if request.format.csv?
        render_search_csv outer_query
      else
        render_search_json outer_query
      end
    end
  end

  # override if different limit required
  def max_per_page
    50
  end

  def render_search_json query
    page = !params['page'].blank? && params['page'].to_s.match(/^\d*$/) ? params['page'].to_i : 1
    per_page = !params['per_page'].blank? && params['per_page'].to_s.match(/^\d*$/) ? params['per_page'].to_i : 10
    per_page = max_per_page if per_page > max_per_page
    q = query.paginate(per_page:per_page, page:page)
    r = q.to_a.collect {|obj| obj_to_json_hash(obj)}
    render json:{results:r, page:page, per_page:per_page}
  end

  def render_search_csv query
    u = current_user

    fields = params['fields'].blank? ? [] : params['fields'].split(',')
    model_fields = fields.collect {|uid| ModelField.find_by_uid(uid.to_sym)}
    model_fields.delete_if {|mf| mf.blank?}
    r = []
    r << model_fields.collect {|mf| mf.can_view?(u) ? mf.label : '[disabled]'}.to_csv(row_sep: nil)

    page = !params['page'].blank? && params['page'].to_s.match(/^\d*$/) ? params['page'].to_i : 1
    per_page = !params['per_page'].blank? && params['per_page'].to_s.match(/^\d*$/) ? params['per_page'].to_i : 1000
    per_page = 1000 if per_page > 1000
    query.paginate(per_page:per_page, page:page).each do |row|
      r << model_fields.collect {|mf| mf.process_export(row, u)}.to_csv(row_sep:nil)
    end
    r << "Maximum rows (#{per_page}) reached." if r.length == (per_page + 1)

    response.headers['Content-Type'] = 'text/csv'
    response.headers['Content-Disposition'] = 'attachment; filename=results.csv'
    # Renders the response without setting the content type
    render body: r.join("\n")
  end

  def search_criterions
    groups = {}
    params.each do |k, v|
      kstr = k.to_s
      case kstr
      when /^sid\d+$/
        num = kstr.sub(/sid/, '').to_i
        groups[num] ||= {}
        groups[num]['field_id'] = v
      when /^sop\d+$/
        num = kstr.sub(/sop/, '').to_i
        groups[num] ||= {}
        groups[num]['operator'] = v
      when /^sv\d+$/
        num = kstr.sub(/sv/, '').to_i
        groups[num] ||= {}
        groups[num]['value'] = v
      end
    end
    r = []
    groups.each do |k, v|
      r << SearchCriterion.new(model_field_uid:v['field_id'], operator:v['operator'], value:v['value'])
    end
    r
  end

  def sort_criterions
    groups = {}
    params.each do |k, v|
      kstr = k.to_s
      case kstr
      when /^oid\d+$/
        num = kstr.sub(/oid/, '').to_i
        groups[num] ||= {}
        groups[num]['field_id'] = v
      when /^oo\d+$/
        num = kstr.sub(/oo/, '').to_i
        groups[num] ||= {}
        groups[num]['order'] = v
      end
    end
    r = []
    groups.keys.sort.each do |k|
      v = groups[k]
      r << SortCriterion.new(model_field_uid:v['field_id'], descending:v['order']=='D')
    end
    r
  end

  # Determines if given model field is able to be viewed by user or not...raises an error
  # if user cannot access a requested field.
  def validate_model_field field_type, model_field_uid, core_module, user
    mf = ModelField.find_by_uid model_field_uid
    # Non-User Accessible fields (.ie database id fields) are intentionally allowed here since they're
    # needed to limit searches to specific object ids (.ie only search for addresses for a certain company id, etc.)
    # They're often tacked on as hidden search parameters.
    if mf.blank? || !mf.can_view?(user)
      raise StatusableError.new("#{field_type} field #{model_field_uid} not found.", 400 )
    end
    if mf.core_module != core_module
      raise StatusableError.new("#{field_type} field #{model_field_uid} is for incorrect module.", 400)
    end
    true
  end


end; end; end;

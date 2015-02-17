require 'open_chain/api/api_entity_jsonizer'

module Api; module V1; class ApiCoreModuleControllerBase < Api::V1::ApiController

  attr_accessor :jsonizer

  def initialize jsonizer = OpenChain::Api::ApiEntityJsonizer.new
    @jsonizer = jsonizer
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

  #override this to implement custom finder
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
      raise StatusableError.new("Path ID #{params[:id]} does not match JSON ID #{obj_hash['id']}.",400) unless params[:id].to_s == obj_hash['id'].to_s
      obj = save_object obj_hash
      obj.update_attributes(last_updated_by: current_user) if obj.respond_to?(:last_updated_by)
      if obj.errors.full_messages.blank?
        obj.create_async_snapshot if obj.respond_to?('create_async_snapshot')
      else
        raise StatusableError.new(obj.errors.full_messages, 400)
      end
      #call do_render instead of using the in memory object so we can benefit from any special optimizations that the implementing classes may do
      render_show core_module
    end
  end

  def requested_field_list
    fields = params[:fields]

    if fields.nil?
      # The mf_uid param name is a holdover from a pre-v1 API call.  Not all clients have
      # been updated yet to use 'fields' instead
      fields = params[:mf_uids]
    end

    # Depending on how params are sent, the fields could be an array or a string.
    # query string like "mf_uid[]=uid&mf_uid[]=uid2" will result in an array (rails takes care of this for us
    # so do most other web application frameworks and lots of tools autogenerate parameters like this so we'll support it)
    # query string like "mf_uid=uid,uid2,uid2" results in a string
    unless fields.is_a?(Enumerable) || fields.blank?
      fields = fields.split(/[,~]/).collect {|v| v.strip!; v.blank? ? nil : v}.compact
    end

    fields = [] if fields.blank?

    fields
  end

  # limit list of fields to render to only those that client requested and can see
  # Render every field if client didn't request any
  def limit_fields field_list
    client_fields = requested_field_list

    if !client_fields.blank?
      # don't to_sym the client fields since symbols aren't gc'ed yet in ruby version we use,
      # change the given field list to strings and compare
      field_list = field_list.map {|f| f.to_s} & client_fields
    end

    user = current_user
    field_list = field_list.delete_if {|uid| mf = ModelField.find_by_uid(uid); !mf.user_accessible? || !mf.can_view?(user)}

    # Change back to symbols
    field_list.map {|f| f.to_sym}
  end

  # load data into object via model fields
  # This method should be avoided unless for some reason you cannot use 
  # update_model_field_attributes on your core_object
  def import_fields base_hash, obj, core_module
    fields = core_module.model_fields {|mf| mf.user_accessible? && base_hash.has_key?(mf.uid.to_s)}
    
    user = current_user
    fields.each_pair do |uid, mf|
      uid = mf.uid.to_s
      # process_import handles checking if user can edit or if field is read_only?
      # so don't bother w/ that here
      mf.process_import(obj,base_hash[uid], user)
    end
    nil
  end

  #render field for json
  def export_field model_field_uid, obj
    jsonizer.export_field current_user, obj, ModelField.find_by_uid(model_field_uid)
  end

  def render_attachments?
    params[:include] && params[:include].match(/attachments/)
  end

  # add attachments array to root of hash
  def render_attachments obj, hash
    hash['attachments'] = Attachment.attachments_as_json(obj)[:attachments]
  end

  #helper method to get model_field_uids for custom fields
  def custom_field_keys core_module
    core_module.model_fields(current_user) {|mf| mf.custom? }.keys
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
      raise StatusableError.new("#{cm.label} Not Found" ,404)
    else
      # Preload the custom values for the object, but don't freeze them....if we freeze them before saving, then the snapshot that's done
      # later potentially won't store off some of the custom values
      CoreModule.walk_object_heirarchy(obj) {|cm, o| o.custom_values.to_a if o.respond_to?(:custom_values)}
      if obj.update_model_field_attributes obj_hash
        raise StatusableError.new("You do not have permission to save this #{cm.label}.", :forbidden) unless obj.can_edit?(current_user)
        obj.update_attributes(last_updated_by: current_user) if obj.respond_to?(:last_updated_by)

        # Now we can freeze the model fields, since all the possible new data should be loaded now.
        # Freezing at this point makes the snapshot run faster, and any actual data load that's done following the save
        obj.freeze_all_custom_values_including_children
      end
    end

    obj
  end

  # Utilizes the internal jsonizer object to generate an object hash 
  # containing the values for the given object for every model field uid listed in the 
  # field_list argument.
  def to_entity_hash(obj, field_list)
    jsonizer.entity_to_hash(current_user, obj, field_list.map {|f| f.to_s})
  end

  def render_search core_module
    user = current_user
    raise StatusableError.new("You do not have permission to view this module.", 401) unless user.view_module?(core_module)
    page = !params['page'].blank? && params['page'].to_s.match(/^\d*$/) ? params['page'].to_i : 1
    per_page = !params['per_page'].blank? && params['per_page'].to_s.match(/^\d*$/) ? params['per_page'].to_i : 10
    per_page = 50 if per_page > 50
    k = core_module.klass.scoped
    
    #apply search criterions
    search_criterions.each do |sc|
      return unless validate_model_field 'Search', sc.model_field_uid, core_module, user
      k = sc.apply(k)
    end

    #apply sort criterions
    sort_criterions.each do |sc|
      return unless validate_model_field 'Sort', sc.model_field_uid, core_module, user
      k = sc.apply(k)
    end
    k = core_module.klass.search_secure(user,k)
    k = k.paginate(per_page:per_page,page:page)
    r = k.to_a.collect {|obj| obj_to_json_hash(obj)}
    render json:{results:r,page:page,per_page:per_page}
  end

  def search_criterions
    groups = {}
    params.each do |k,v|
      kstr = k.to_s
      case kstr
      when /^sid\d+$/
        num = kstr.sub(/sid/,'').to_i
        groups[num] ||= {}
        groups[num]['field_id'] = v
      when /^sop\d+$/
        num = kstr.sub(/sop/,'').to_i
        groups[num] ||= {}
        groups[num]['operator'] = v
      when /^sv\d+$/
        num = kstr.sub(/sv/,'').to_i
        groups[num] ||= {}
        groups[num]['value'] = v
      end
    end
    r = []
    groups.each do |k,v|
      r << SearchCriterion.new(model_field_uid:v['field_id'],operator:v['operator'],value:v['value'])
    end
    r
  end

  def sort_criterions
    groups = {}
    params.each do |k,v|
      kstr = k.to_s
      case kstr
      when /^oid\d+$/
        num = kstr.sub(/oid/,'').to_i
        groups[num] ||= {}
        groups[num]['field_id'] = v
      when /^oo\d+$/
        num = kstr.sub(/oo/,'').to_i
        groups[num] ||= {}
        groups[num]['order'] = v
      end
    end
    r = []
    groups.keys.sort.each do |k|
      v = groups[k]
      r << SortCriterion.new(model_field_uid:v['field_id'],descending:v['order']=='D')
    end
    r
  end

  # Determines if given model field is able to be viewed by user or not...raises an error
  # if user cannot access a requested field.
  def validate_model_field field_type, model_field_uid, core_module, user
    mf = ModelField.find_by_uid model_field_uid
    if mf.blank? || !mf.user_accessible || !mf.can_view?(user)
      raise StatusableError.new("#{field_type} field #{model_field_uid} not found.", 400 )
    end
    if mf.core_module != core_module
      raise StatusableError.new("#{field_type} field #{model_field_uid} is for incorrect module.", 400)
    end
    true
  end


end; end; end;
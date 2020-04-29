# If you include this module, you MUST implement a `core_module` method.
module OpenChain; module Api; module V1; module ApiModelFieldSupport
  extend ActiveSupport::Concern

  def custom_field_keys core_module
    core_module.model_fields(current_user) {|mf| mf.custom? }.keys
  end

  def field_list core_module
    ModelField.find_by_module_type(core_module).map(&:uid)
  end

  def requested_field_list http_params: params
    fields = http_params[:fields]

    if fields.nil?
      # The mf_uid param name is a holdover from a pre-v1 API call.  Not all clients have
      # been updated yet to use 'fields' instead
      fields = http_params[:mf_uids]
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
  def limit_fields field_list, user: current_user, http_params: params
    client_fields = requested_field_list http_params: http_params

    if !client_fields.blank?
      # don't to_sym the client fields since symbols aren't gc'ed yet in ruby version we use,
      # change the given field list to strings and compare
      field_list = field_list.map {|f| f.to_s} & client_fields
    end

    field_list = field_list.delete_if {|uid| !ModelField.find_by_uid(uid).can_view?(user) }

    # Change back to symbols
    field_list.map {|f| f.to_sym}
  end

  # This method basically takes the place of limit fields, requested_field_list and include checks
  # and rolls them all into a single method.
  # You must pass an associations hash which is the name of the associations that may be included in the field
  # list (assuming a corresponding include param is present in the request).
  #
  # An associations hash for something like an entry might look like: {"commercial_invoices" => CoreModule::COMMERCIAL_INVOICE,
  # "commercial_invoice_lines" => CoreModule::COMMERCIAL_INVOICE_LINES, "broker_invoices" => CoreModule::BROKER_INVOICE
  #
  #
  def all_requested_model_fields core_module, http_params: params, user: current_user, include_all_modules: false, associations: {}
    modules = [core_module]
    # If no include mappings were given, we'll assume the caller wants all fields from all modules available
    # Only include core modules associated with the associations that were requested
    associations.each_pair do |association, core_module|
      modules << core_module if include_all_modules || include_association?(association, http_params: http_params)
    end

    model_fields = []
    # Retrieve the list of fields the user requested returned, use to filter out the
    # model fields from all the modules below
    client_fields = Set.new(requested_field_list http_params: http_params)

    Array.wrap(modules).each do |core_module|
      # return even user inaccessible fields (which are basically just database id fields)..these are marked this way primarily just
      # so they're hidden from the search screen...they should be accessible from the API.
      mf_hash = core_module.model_fields(user, true) do |mf|
        client_fields.blank? || client_fields.include?(mf.uid)
      end

      model_fields.push *mf_hash.values
    end

    model_fields
  end

  def all_requested_model_field_uids core_module, http_params: params, user: current_user, include_all_modules: false, associations: {}
    all_requested_model_fields(core_module, http_params: http_params, user: current_user, include_all_modules: include_all_modules, associations: associations).map {|mf| mf.uid }
  end

end; end; end; end;
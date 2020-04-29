require 'open_chain/api/api_client'

# Provides show / create / update / search api method implementations.
#
# Methods including / extending this module need to provide
# an implemetnation of the core_module method for which api calls should reference.

module OpenChain; module Api; module CoreApiActions

  def entity_name
    core_module.klass.name.underscore
  end

  def module_path
    core_module.klass.name.pluralize.underscore
  end

  def extract_id_from_params params
    entity = params[entity_name] ? params[entity_name] : params[entity_name.to_sym]
    id = entity.try(:[], 'id') ? entity['id'] : entity.try(:[], :id)
    raise "All API update calls require an 'id' in the attribute hash." unless id
    id
  end

  def mf_uid_list_to_param uids
    uids.blank? ? {} : {"fields" => uids.inject("") {|i, uid| i += "#{uid.to_s},"}[0..-2]}
  end

  def show id, mf_uids
    get("/#{module_path}/#{id}", mf_uid_list_to_param(mf_uids))
  end

  def create obj_hash
    post("/#{module_path}", obj_hash)
  end

  def update obj_hash
    id = extract_id_from_params obj_hash
    put("/#{module_path}/#{id}", obj_hash)
  end

  def search fields:, search_criterions: , sorts: [], page: 1, per_page: 50
    request_hash = mf_uid_list_to_param(fields).merge({"page" => page.to_s, "per_page" => per_page.to_s})

    search_criterions.each_with_index do |sc, index|
      request_hash["sid#{index}"] = sc.model_field_uid
      request_hash["sop#{index}"] = sc.operator
      request_hash["sv#{index}"] = sc.value
    end

    sorts.each_with_index do |s, index|
      request_hash["oid#{index}"] = s.model_field_uid
      request_hash["oo#{index}"] = "D" if s.descending?
    end

    get("/#{module_path}", request_hash)
  end

  def get_request_wrapper
    yield
  rescue => e
    if OpenChain::Api::ApiClient.not_found_error?(e)
      return {entity_name => nil}
    else
      raise e
    end
  end

end; end; end;
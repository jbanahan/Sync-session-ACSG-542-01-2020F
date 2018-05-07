require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class GroupApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::GROUP, jsonizer: jsonizer)
  end

  def obj_to_json_hash group
    fields = all_requested_model_field_uids(CoreModule::GROUP)
    hash = to_entity_hash(group, fields)
    if include_association? "users"
      hash['users'] = group.users.map {|u| u.api_hash(include_permissions: false)}
      add_companies(hash['users'])
    end
    hash
  end

  def add_companies users
    co = Company.where(id: users.map {|u| u[:company_id] }.uniq).inject({}) {|acc, c| acc[c.id] = {id: c.id, name: c.name, system_code: c.system_code}; acc}
    users.map! {|u| u.merge({"company" => co[u[:company_id]]})}
  end
end; end; end; end;
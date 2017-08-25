require 'open_chain/api/api_client'
require 'open_chain/api/core_api_actions'

module OpenChain; module Api; class ProductApiClient < ApiClient
  include OpenChain::Api::CoreApiActions

  def core_module
    CoreModule::PRODUCT
  end

  def find_by_uid uid, mf_uids
    get_request_wrapper { get("/#{module_path}/by_uid", {uid: uid}.merge(mf_uid_list_to_param(mf_uids))) }
  end

end; end; end
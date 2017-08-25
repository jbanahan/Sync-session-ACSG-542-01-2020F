require 'open_chain/api/api_client'
require 'open_chain/api/core_api_actions'

module OpenChain; module Api; class OrderApiClient < ApiClient
  include OpenChain::Api::CoreApiActions

  def core_module
    CoreModule::ORDER
  end

  def find_by_order_number order_number, mf_uids
    get_request_wrapper { get("/#{module_path}/by_order_number", {order_number: order_number}.merge(mf_uid_list_to_param(mf_uids))) }
  end

end; end; end
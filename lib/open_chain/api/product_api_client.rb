require 'open_chain/api/api_client'

module OpenChain; module Api; class ProductApiClient < ApiClient

  def find_by_id id, mf_uids
    send_request("/products/by_id/#{id}", mf_uid_list_to_param(mf_uids))
  end

  def find_by_uid uid, mf_uids
    send_request("/products/by_uid/#{uid}", mf_uid_list_to_param(mf_uids))
  end

  def find_model_fields
    send_request("/products/model_fields")
  end
end; end; end
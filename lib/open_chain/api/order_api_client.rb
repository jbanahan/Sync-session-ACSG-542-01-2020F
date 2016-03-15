require 'open_chain/api/api_client'

module OpenChain; module Api; class OrderApiClient < ApiClient

  def find_by_order_number order_number, mf_uids
    get("/orders/by_order_number", {order_number: order_number}.merge(mf_uid_list_to_param(mf_uids)))
  rescue => e
    if not_found_error?(e)
      return {'order' => nil}
    else
      raise e
    end
  end

  def show id, mf_uids
    get("/orders/#{id}", mf_uid_list_to_param(mf_uids))
  end

  def create order_hash
    post("/orders", order_hash)
  end

  def update order_hash
    id = extract_id_from_params order_hash, 'order'

    put("/orders/#{id}", order_hash)
  end

end; end; end
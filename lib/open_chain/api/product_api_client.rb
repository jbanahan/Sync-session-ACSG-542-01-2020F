require 'open_chain/api/api_client'

module OpenChain; module Api; class ProductApiClient < ApiClient

  def find_by_uid uid, mf_uids
    get("/products/by_uid", {uid: uid}.merge(mf_uid_list_to_param(mf_uids)))
  rescue => e
    if not_found_error?(e)
      return {'product' => nil}
    else
      raise e
    end
  end

  def show id, mf_uids
    get("/products/#{id}", mf_uid_list_to_param(mf_uids))
  end

  def create product_hash
    post("/products", product_hash)
  end

  def update product_hash
    id = extract_id_from_params product_hash, 'product'

    put("/products/#{id}", product_hash)
  end

end; end; end
require 'open_chain/api/api_client'

module OpenChain; module Api; class ProductApiClient < ApiClient

  def find_by_uid uid, mf_uids
    get("/products/by_uid/#{uid}", mf_uid_list_to_param(mf_uids))
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
    product = product_hash['product'] ? product_hash['product'] : product_hash[:product]
    id = product.try(:[], 'id') ? product['id'] : product.try(:[], :id)
    raise "All product update calls require an 'id' in the attribute hash." unless id

    put("/products/#{id}", product_hash)
  end

end; end; end
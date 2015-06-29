module Api; module V1; class AddressesController < ApiController

  def autocomplete
    result = Address.where('name like ?',"%#{params[:n]}%").where(in_address_book:true)
    render json: result, root: false
  end

  def create
    address = Address.create! params[:address]
    render json: address
  end

end; end; end
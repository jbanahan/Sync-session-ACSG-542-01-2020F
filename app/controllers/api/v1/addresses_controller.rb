module Api; module V1; class AddressesController < ApiController

  def autocomplete
    result = Address.where('name like ?',"%#{params[:n]}%").where(in_address_book:true)
    render json: result.map {|address| {name:address.name, full_address:address.full_address, id:address.id} }
  end

  def create
    address = Address.create! params[:address]
    render json: address
  end

end; end; end
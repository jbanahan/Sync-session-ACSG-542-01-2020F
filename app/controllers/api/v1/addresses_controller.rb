module Api; module V1; class AddressesController < ApiController

  def autocomplete
    result = Address.where('name LIKE %?%',params[:n]).where(in_address_book:true)
    render json: {addresses: result}
  end

  def create

  end

end; end; end
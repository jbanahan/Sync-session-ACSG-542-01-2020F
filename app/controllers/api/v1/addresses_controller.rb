module Api; module V1; class AddressesController < ApiController

  def autocomplete
    json = []
    if !params[:n].blank?
      result = Address.where('addresses.name like ?',"%#{params[:n]}%").where(in_address_book:true).joins(:company).where(Company.secure_search(current_user))
      result = result.order(:name)
      result = result.limit(10)
      json = result.map {|address| {name:address.name, full_address:address.full_address, id:address.id} }
    end
    
    render json: json
  end

  def create
    address = Address.create! params[:address]
    render json: address
  end

end; end; end
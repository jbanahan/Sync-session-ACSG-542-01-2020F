module Api; module V1; class ProductsController < ApiController

  def show
    show_module Product
  end

  def by_uid
    render_obj Product.where(unique_identifier: params[:uid]).first
  end

  def model_fields
    render_model_field_list CoreModule::PRODUCT
  end
  
end; end; end
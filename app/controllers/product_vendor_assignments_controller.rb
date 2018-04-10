class ProductVendorAssignmentsController < ApplicationController
  def index
    flash.keep
    redirect_to advanced_search CoreModule::PRODUCT_VENDOR_ASSIGNMENT, params[:force_search]
  end
end

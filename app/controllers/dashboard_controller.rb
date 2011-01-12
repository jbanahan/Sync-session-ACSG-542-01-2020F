class DashboardController < ApplicationController

  before_filter :require_user

	def show_main
	  @products_without_hts = products_without_hts
    render :layout => 'one_col'
	end
	
	private
	def products_without_hts
	  Product.
	   joins("LEFT OUTER JOIN classifications on classifications.product_id = products.id").
	   joins("LEFT OUTER JOIN tariff_records on tariff_records.classification_id = classifications.id").
	   where("tariff_records.id is null").all
	end
	
end

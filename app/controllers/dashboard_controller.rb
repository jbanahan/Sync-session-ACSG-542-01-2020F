class DashboardController < ApplicationController

  before_filter :require_user

	def show_main
	  @products_without_hts = products_without_hts
	  @order_lines_not_on_shipments = order_lines_not_on_shipments
	  @piece_sets_not_received = piece_sets_not_received
	  @products_not_approved = products_not_approved
    render :layout => 'one_col'
	end
	
	private
	def products_not_approved
	  Product.
	   joins("LEFT OUTER JOIN status_rules on status_rules.id = products.status_rule_id").
	   where("NOT status_rules.name = 'Approved'").all
	end
	def products_without_hts
	  Product.
	   joins("LEFT OUTER JOIN classifications on classifications.product_id = products.id").
	   joins("LEFT OUTER JOIN tariff_records on tariff_records.classification_id = classifications.id").
	   where("tariff_records.id is null AND classifications.country_id = (SELECT countries.ID from countries where countries.iso_code = 'US')").all
	end
	
	def order_lines_not_on_shipments
	  OrderLine.
	   joins("LEFT OUTER JOIN piece_sets on order_lines.id = piece_sets.order_line_id").
	   joins("LEFT OUTER JOIN shipments on piece_sets.shipment_id = shipments.id").
	   where("shipments.id is null").all
	end
	
	def piece_sets_not_received
	  PieceSet.where("shipment_id is not null and inventory_in_id is null").all
	end
	
end

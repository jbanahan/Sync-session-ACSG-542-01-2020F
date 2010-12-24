class DashboardController < ApplicationController

  before_filter :require_user

	def show_main
	  @late_shipments = get_late_shipments
    render :layout => 'one_col'
	end
	
	private
	def get_late_shipments
	  return Shipment.where("ata is null and eta < ?",Time.new)
	end
	
end

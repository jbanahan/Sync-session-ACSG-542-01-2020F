class ShipmentsController < ApplicationController
  
	def root_class
	  Shipment
	end
	
  def index
    flash.keep
    redirect_to advanced_search CoreModule::SHIPMENT, params[:force_search]
  end

  # GET /shipments/1
  # GET /shipments/1.xml
  def show
    @shipment_id = params[:id]
    @no_action_bar = true
  end

  # GET /shipments/new
  # GET /shipments/new.xml
  def new
    s = Shipment.new
    action_secure(s.can_edit?(current_user),s,{:verb => "create",:module_name=>"shipment"}) {
      @no_action_bar = true
    }
  end

  # GET /shipments/1/edit
  def edit
    redirect_to "#{shipment_path(params[:id])}#/#{params[:id]}/edit"
  end
end

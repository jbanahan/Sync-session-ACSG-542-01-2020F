require 'open_chain/custom_handler/shipment_download_generator'
require 'open_chain/custom_handler/j_jill/j_jill_shipment_download_generator'

class ShipmentsController < ApplicationController
  include BulkSendToTestSupport

  def set_page_title
    @page_title ||= 'Shipment'
  end

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
    action_secure(s.can_edit?(current_user), s, {:verb => "create", :module_name=>"shipment"}) {
      @no_action_bar = true
    }
  end

  # GET /shipments/1/edit
  def edit
    redirect_to "#{shipment_path(params[:id])}#!/#{params[:id]}/edit"
  end

  def download
    s = Shipment.where(id: params[:id]).includes(:importer).first

    action_secure(s.can_edit?(current_user), s, {:verb => "download", :module_name=>"shipment"}) {
      generator = case s.importer.try(:system_code)
        when "JJILL"
          OpenChain::CustomHandler::JJill::JJillShipmentDownloadGenerator
        else
          OpenChain::CustomHandler::ShipmentDownloadGenerator
        end
      builder = XlsxBuilder.new
      generator.new.generate(builder, s, current_user)
      send_builder_data builder, "#{s.reference}"
    }
  end
end

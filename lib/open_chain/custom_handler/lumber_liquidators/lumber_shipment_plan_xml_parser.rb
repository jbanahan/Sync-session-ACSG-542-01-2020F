require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberShipmentPlanXmlParser
  include OpenChain::CustomHandler::XmlHelper
  extend OpenChain::IntegrationClientParser

  def self.parse data, opts={}
    parse_dom REXML::Document.new(data), opts
  end

  def self.parse_dom dom, opts={}
    self.new.parse_dom(dom, opts)
  end

  def self.integration_folder
    ["ll/ll_shipment_plan", "/home/ubuntu/ftproot/chainroot/ll/ll_shipment_plan"]
  end

  def parse_dom dom, opts={}
    root = dom.root
    raise "Incorrect root element, '#{root.name}'.  Expecting 'ShipmentPlanMessage'." unless root.name == 'ShipmentPlanMessage'

    # Although pulled from a detail field, per SOW 1441, it's safe to assume that there's 'only one VFI reference
    # number per shipment plan.'
    shipment_ref = get_element_text root, "ShipmentPlanList/ShipmentPlan/ShipmentPlanItemList/ShipmentPlanItem/SellerId"
    raise "XML must have Shipment Reference Number at /ShipmentPlanList/ShipmentPlan/ShipmentPlanItemList/ShipmentPlanItem/SellerId." if shipment_ref.blank?

    shipment_plan_name = get_element_text root, "ShipmentPlanList/ShipmentPlan/ShipmentPlanHeader/ShipmentPlanName"
    raise "XML must have Shipment Plan Name at /ShipmentPlanList/ShipmentPlan/ShipmentPlanHeader/ShipmentPlanName." if shipment_plan_name.blank?

    shipment = nil
    Lock.acquire("Shipment-#{shipment_ref}") do
      shipment = Shipment.where(reference:shipment_ref).first
    end

    if shipment
      Lock.with_lock_retry(shipment) do
        shipment.importer_reference = shipment_plan_name

        shipment.save!
        shipment.create_snapshot(User.integration, nil, opts[:key])
      end
    else
      generate_missing_shipment_email shipment_ref
    end
  end

  private
    def generate_missing_shipment_email shipment_ref
      body_text = "A plan name was received for shipment '#{shipment_ref}', but a shipment with a matching reference number could not be found."
      OpenMailer.send_simple_html('ll-support@vandegriftinc.com', 'Lumber Liquidators Shipment Plan: Missing Shipment', body_text).deliver!
    end

    def get_element_text root, xpath
      elem_val = REXML::XPath.first(root, xpath)
      elem_val ? elem_val.text : nil
    end

end; end; end; end;

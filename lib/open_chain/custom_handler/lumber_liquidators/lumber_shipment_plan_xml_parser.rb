require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberShipmentPlanXmlParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::IntegrationClientParser

  def self.parse_file data, log, opts={}
    parse_dom REXML::Document.new(data), log, opts
  end

  def self.parse_dom dom, log, opts={}
    self.new.parse_dom(dom, log, opts)
  end

  def self.integration_folder
    ["ll/ll_shipment_plan", "/home/ubuntu/ftproot/chainroot/ll/ll_shipment_plan"]
  end

  def parse_dom dom, log, opts={}
    root = dom.root
    log.error_and_raise "Incorrect root element, '#{root.name}'.  Expecting 'ShipmentPlanMessage'." unless root.name == 'ShipmentPlanMessage'

    log.company = Company.where(system_code: "LUMBER").first

    # Although pulled from a detail field, per SOW 1441, it's safe to assume that there's 'only one VFI reference
    # number per shipment plan.'
    shipment_ref = get_element_text root, "ShipmentPlanList/ShipmentPlan/ShipmentPlanItemList/ShipmentPlanItem/SellerId"
    log.reject_and_raise "XML must have Shipment Reference Number at /ShipmentPlanList/ShipmentPlan/ShipmentPlanItemList/ShipmentPlanItem/SellerId." if shipment_ref.blank?

    log.add_identifier InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, shipment_ref

    shipment_plan_name = get_element_text root, "ShipmentPlanList/ShipmentPlan/ShipmentPlanHeader/ShipmentPlanName"
    log.reject_and_raise "XML must have Shipment Plan Name at /ShipmentPlanList/ShipmentPlan/ShipmentPlanHeader/ShipmentPlanName." if shipment_plan_name.blank?

    shipment = nil
    Lock.acquire("Shipment-#{shipment_ref}") do
      shipment = Shipment.where(reference:shipment_ref).first
    end

    if shipment
      log.set_identifier_module_info InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, Shipment.to_s, shipment.id

      Lock.with_lock_retry(shipment) do
        shipment.importer_reference = shipment_plan_name

        shipment.save!
        shipment.create_snapshot(User.integration, nil, opts[:key])
      end
    else
      log.add_reject_message "Shipment matching reference number '#{shipment_ref}' could not be found."
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

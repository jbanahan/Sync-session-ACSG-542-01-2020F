require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberBookingConfirmationXmlParser
  include OpenChain::CustomHandler::XmlHelper
  extend OpenChain::IntegrationClientParser

  def self.parse data, opts={}
    parse_dom REXML::Document.new(data), opts
  end

  def self.parse_dom dom, opts={}
    self.new.parse_dom(dom, opts)
  end

  def self.integration_folder
    ["ll/ll_booking_confirmation", "/home/ubuntu/ftproot/chainroot/ll/ll_booking_confirmation"]
  end

  def parse_dom dom, opts={}
    root = dom.root
    raise "Incorrect root element, '#{root.name}'.  Expecting 'ShippingOrderMessage'." unless root.name == 'ShippingOrderMessage'

    elem_shipping_order = REXML::XPath.first(root,'ShippingOrder')
    shipment_ref = et(elem_shipping_order, 'ShippingOrderNumber')
    raise "XML must have Shipment Reference Number at /ShippingOrder/ShippingOrderNumber." if shipment_ref.blank?

    shipment = nil
    Lock.acquire("Shipment-#{shipment_ref}") do
      shipment = Shipment.where(reference:shipment_ref).first
    end

    if shipment
      Lock.with_lock_retry(shipment) do
        shipment.booking_number = et(elem_shipping_order, 'UserDefinedReferenceField2')
        shipment.booking_cutoff_date = parse_date(et(elem_shipping_order, 'CargoCutOffDate', true))
        shipment.booking_approved_date = parse_date(et(elem_shipping_order, 'UserDefReferenceDate2', true))
        shipment.booking_confirmed_date = ActiveSupport::TimeZone['UTC'].now
        shipment.booking_est_departure_date = parse_date(et(elem_shipping_order, 'ETDPortOfLoadDate', true))
        shipment.est_departure_date = shipment.booking_est_departure_date if shipment.est_departure_date.nil?
        shipment.booking_est_arrival_date = parse_date(et(elem_shipping_order, 'ETAPlaceOfDeliveryDate', true))
        shipment.booking_vessel = et(elem_shipping_order, 'Vessel')
        shipment.vessel = shipment.booking_vessel if shipment.vessel.blank?
        shipment.booking_voyage = et(elem_shipping_order, 'Voyage')
        shipment.voyage = shipment.booking_voyage if shipment.voyage.blank?

        elem_carrier_code = REXML::XPath.first(elem_shipping_order,"PartyInfo[Type='Carrier']/Code")
        shipment.booking_carrier = elem_carrier_code ? elem_carrier_code.text : nil
        shipment.vessel_carrier_scac = shipment.booking_carrier if shipment.vessel_carrier_scac.blank?

        shipment.save!
        shipment.create_snapshot(User.integration, nil, opts[:key])
      end
    else
      generate_missing_shipment_email shipment_ref
    end
  end

  private
    def parse_date date_str
      ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse date_str
    end

    def generate_missing_shipment_email shipment_ref
      body_text = "A booking confirmation was received for shipment '#{shipment_ref}', but a shipment with a matching reference number could not be found."
      OpenMailer.send_simple_html('ll-support@vandegriftinc.com', 'Lumber Liquidators Booking Confirmation: Missing Shipment', body_text).deliver!
    end

end; end; end; end;

require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberGtnAsnParser
    include OpenChain::CustomHandler::XmlHelper
    include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
    extend OpenChain::IntegrationClientParser

    CDEF_MAP = {
      '9'=>:ord_asn_arrived,
      '7041'=>:ord_asn_booking_approved,
      '26'=>:ord_asn_booking_submitted,
      '6'=>:ord_asn_departed,
      '10'=>:ord_asn_discharged,
      '24'=>:ord_asn_empty_return,
      '7011'=>:ord_asn_fcr_created,
      '7013'=>:ord_asn_gate_in,
      '8231'=>:ord_asn_gate_out,
      '5'=>:ord_asn_loaded_at_port
    }

    def self.parse data, opts={}
      parse_dom REXML::Document.new(data), opts
    end

    def self.parse_dom dom, opts={}
      self.new(opts).parse_dom dom
    end

    def initialize opts
      @cdefs = self.class.prep_custom_definitions [
        :ord_asn_arrived,:ord_asn_booking_approved,:ord_asn_booking_submitted,:ord_asn_departed,
        :ord_asn_discharged,:ord_asn_empty_return,:ord_asn_fcr_created,:ord_asn_gate_in,
        :ord_asn_gate_out,:ord_asn_loaded_at_port
      ]
    end

    def parse_dom dom
      root = dom.root
      raise "Bad root element name \"#{root.name}\". Expecting ASNMessage." unless root.name=='ASNMessage'
      get_orders(root).each do |ord_num, ord_hash|
        update_order(ord_hash[:order],ord_hash[:element])
      end
    end

    def update_order ord, element
      get_dates(element).each do |cdef,val|
        ord.update_custom_value!(cdef,val)
      end
      ord.create_snapshot User.integration
    end

    def get_dates line_item_element
      found_dates = {}
      REXML::XPath.each(line_item_element,'./MilestoneMessage/OneReferenceMultipleMilestones/MilestoneInfo') do |el|
        code = et(el,'MilestoneTypeCode')
        cdef = @cdefs[CDEF_MAP[code]]
        date = parse_date(el)
        next unless cdef && date
        found_dates[cdef] = date
      end
      found_dates
    end

    def parse_date el
      inner_el = REXML::XPath.first(el,'MilestoneTime[@timeZone="LT"]')
      return nil if inner_el.blank?
      date_attr = inner_el.attribute('dateTime')
      return nil if date_attr.blank?
      date_str = date_attr.value
      return nil if date_str.blank?
      DateTime.iso8601(date_str)
    end

    def get_orders root
      r = {}
      REXML::XPath.each(root,'./ASN/Container/LineItems') do |el|
        order_number = et(el,'PONumber')
        r[order_number] = {element:el}
      end
      orders = Order.includes(:custom_values).where('order_number IN (?)',r.keys.to_a).to_a
      if r.size != orders.size
        missing_order_numbers = r.keys.to_a - orders.map(&:order_number)
        raise "ASN Failed because order(s) not found in database: #{missing_order_numbers}"
      else
        orders.each {|ord| r[ord.order_number][:order] = ord}
      end
      r
    end
end; end; end; end

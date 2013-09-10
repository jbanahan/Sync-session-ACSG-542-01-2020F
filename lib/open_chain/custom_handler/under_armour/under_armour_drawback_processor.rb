require 'open_chain/drawback_processor'
require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'
module OpenChain; module CustomHandler; module UnderArmour
  class UnderArmourDrawbackProcessor < OpenChain::DrawbackProcessor
    include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport

    def initialize
      @cdefs = self.class.prep_custom_definitions [:po,:del_date,:coo,:size]
    end

    def find_shipment_lines commercial_invoice_line
      entry = commercial_invoice_line.entry
      po_search = SearchCriterion.new(:model_field_uid=>"*cf_#{@cdefs[:po].id}",:operator=>"eq",:value=>commercial_invoice_line.po_number)
      no_past_search = SearchCriterion.new(:model_field_uid=>"*cf_#{@cdefs[:del_date].id}",:operator=>"gt",:value=>entry.arrival_date-1.day)
      no_past_search.apply po_search.apply ShipmentLine.select("shipment_lines.*").joins(:shipment).joins(:product).where("products.unique_identifier = ?",commercial_invoice_line.part_number).
        where("shipments.importer_id = ? OR shipments.importer_id IN (SELECT parent_id FROM linked_companies WHERE child_id = ?)",entry.importer_id,entry.importer_id)
    end
    
    def get_part_number(shipment_line, commerical_invoice_line)
      "#{shipment_line.product.unique_identifier}-#{shipment_line.get_custom_value(@cdefs[:size]).value}+#{get_country_of_origin(shipment_line,commerical_invoice_line)}"
    end

    def get_country_of_origin(shipment_line, commercial_invoice_line) 
      !commercial_invoice_line.country_origin_code.blank? ? commercial_invoice_line.country_origin_code : shipment_line.get_custom_value(@cdefs[:coo]).value
    end

    def get_received_date(shipment)
      shipment.get_custom_value(@cdefs[:del_date]).value
    end
  end
end; end; end

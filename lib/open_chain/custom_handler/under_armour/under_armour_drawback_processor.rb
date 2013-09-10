require 'open_chain/drawback_processor'
require 'open_chain/custom_handler/custom_definition_support'
module OpenChain; module CustomHandler; module UnderArmour
  class UnderArmourDrawbackProcessor < OpenChain::DrawbackProcessor
    include ::OpenChain::CustomHandler::CustomDefinitionSupport

    def initialize
      
    end

    def find_shipment_lines commercial_invoice_line
      entry = commercial_invoice_line.entry
      po_search = SearchCriterion.new(:model_field_uid=>"*cf_#{po_custom_def.id}",:operator=>"eq",:value=>commercial_invoice_line.po_number)
      no_past_search = SearchCriterion.new(:model_field_uid=>"*cf_#{delivery_custom_def.id}",:operator=>"gt",:value=>entry.arrival_date-1.day)
      no_past_search.apply po_search.apply ShipmentLine.select("shipment_lines.*").joins(:shipment).joins(:product).where("products.unique_identifier = ?",commercial_invoice_line.part_number).
        where("shipments.importer_id = ? OR shipments.importer_id IN (SELECT parent_id FROM linked_companies WHERE child_id = ?)",entry.importer_id,entry.importer_id)
    end
    
    def get_part_number(shipment_line, commerical_invoice_line)
      "#{shipment_line.product.unique_identifier}-#{shipment_line.get_custom_value(size_custom_def).value}+#{get_country_of_origin(shipment_line,commerical_invoice_line)}"
    end

    def get_country_of_origin(shipment_line, commercial_invoice_line) 
      !commercial_invoice_line.country_origin_code.blank? ? commercial_invoice_line.country_origin_code : shipment_line.get_custom_value(country_origin_custom_def).value
    end

    def get_received_date(shipment)
      shipment.get_custom_value(delivery_custom_def).value
    end

    private
    def po_custom_def
      @po_custom_def ||= CustomDefinition.find_by_label_and_module_type 'PO Number', 'ShipmentLine'
    end
    def delivery_custom_def
      @delivery_custom_def ||= CustomDefinition.find_by_label_and_module_type 'Delivery Date', 'Shipment'
    end
    def country_origin_custom_def
      @country_origin_custom_def ||= CustomDefinition.find_by_label_and_module_type "Country of Origin", "ShipmentLine"
    end
    def size_custom_def
      @size_custom_def ||= CustomDefinition.find_by_label_and_module_type "Size", "ShipmentLine"
    end
  end
end; end; end

require 'open_chain/drawback_processor'
module OpenChain
  class JCrewDrawbackProcessor < OpenChain::DrawbackProcessor
    
    def find_shipment_lines commercial_invoice_line
      entry = commercial_invoice_line.entry
      po_search = SearchCriterion.new(:model_field_uid=>"*cf_#{po_custom_def.id}",:operator=>"eq",:value=>commercial_invoice_line.po_number)
      received_date_search = SearchCriterion.new(:model_field_uid=>"*cf_#{delivery_custom_def.id}",:operator=>'gt',:value=>entry.arrival_date-1.day)
      received_date_search.apply po_search.apply ShipmentLine.select("shipment_lines.*").joins(:shipment).joins(:product).where("products.unique_identifier = ?",commercial_invoice_line.part_number).
        where("shipments.importer_id = ? OR shipments.importer_id IN (SELECT parent_id FROM linked_companies WHERE child_id = ?)",entry.importer_id,entry.importer_id).
        where("shipments.reference = ?",entry.entry_number)
    end

    def get_received_date(shipment_line)
      shipment_line.shipment.get_custom_value(delivery_custom_def).value
    end
    
    def get_country_of_origin(shipment_line, commercial_invoice_line) 
      commercial_invoice_line.country_origin_code
    end

    def get_part_number s_line, c_line
      "#{c_line.part_number}#{s_line.get_custom_value(color_custom_def).value}#{s_line.get_custom_value(size_custom_def).value}"
    end
    private
    def po_custom_def
      @po_custom_def ||= CustomDefinition.find_by_label_and_module_type 'PO Number', 'ShipmentLine'
    end
    
    def delivery_custom_def
      @delivery_custom_def ||= CustomDefinition.find_by_label_and_module_type 'Delivery Date', 'Shipment'
    end
    def color_custom_def
      @color_custom_def ||= CustomDefinition.find_by_label_and_module_type "Color", "ShipmentLine"
    end
    def size_custom_def
      @size_custom_def ||= CustomDefinition.find_by_label_and_module_type "Size", "ShipmentLine"
    end
  end
end

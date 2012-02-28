module OpenChain
  class UnderArmourDrawbackProcessor
    
    # Links a commercial invoice line to shipment lines if the commercial invoice line is not already linked and shipment line is not already linked
    # Takes an optional change record which should ve linked to the commercial invoice line. If it is not null, then messages will be added (but not saved) and the
    # failure flag will be set if no matches are made
    def link_commercial_invoice_line c_line, change_record=nil
      entry = c_line.commercial_invoice.entry
      cr = change_record.nil? ? ChangeRecord.new : change_record #use a junk change record to make the rest of the coding easire if nil was passed
      if !c_line.piece_sets.where("shipment_line_id is not null").blank?
        cr.add_message "Line is already linked to shipments, skipped.", true #true sets change record failure flag
        return
      end
      po_search = SearchCriterion.new(:model_field_uid=>"*cf_#{po_custom_def.id}",:operator=>"eq",:value=>c_line.po_number)
      delivery_date_search = SearchCriterion.new(:model_field_uid=>"*cf_#{delivery_custom_def.id}",:operator=>"lt",:value=>entry.arrival_date+30.days)
      no_past_search = SearchCriterion.new(:model_field_uid=>"*cf_#{delivery_custom_def.id}",:operator=>"gt",:value=>entry.arrival_date-1.day)
      found = no_past_search.apply delivery_date_search.apply po_search.apply ShipmentLine.select("shipment_lines.*").joins(:shipment).joins(:product).where("products.unique_identifier = ?",c_line.part_number)
      found.each do |s_line|
        if s_line.commercial_invoice_lines.blank?
          s_line.linked_commercial_invoice_line_id = c_line.id #force the piece set to be created on save
          s_line.save!
          cr.add_message "Matched to Shipment: #{s_line.shipment.reference}, Line: #{s_line.line_number}"
        end
      end
    end

    # Makes drawback import lines for all commerical invoice line / shipment line pairs already connected to the given commercial invoice line
    def make_drawback_import_lines c_line, change_record=nil
      cr = change_record.nil? ? ChangeRecord.new : change_record
      r = [] 
      piece_sets = c_line.piece_sets.where("shipment_line_id is not null and drawback_import_line_id is null")
      if piece_sets.blank?
        cr.add_message "Line does not have any unallocated shipment matches.", true
        return r
      end
      entry = c_line.commercial_invoice.entry
      tariff = c_line.commercial_invoice_tariffs.first #Under Armour will only have one
      total_units = BigDecimal("0.00")
      piece_sets.each {|ps| total_units += ps.quantity}
      piece_sets.each do |ps|
        ship_line = ps.shipment_line
        shipment = ship_line.shipment
        d = DrawbackImportLine.new(:entry_number=>entry.entry_number,
          :import_date=>entry.arrival_date,
          :received_date=>shipment.get_custom_value(delivery_custom_def).value,
          :port_code=>entry.entry_port_code,
          :box_37_duty => entry.total_duty,
          :box_40_duty => entry.total_duty_direct,
          :country_of_origin_code => ship_line.get_custom_value(country_origin_custom_def).value,
          :product_id => ship_line.product_id,
          :part_number=>"#{ship_line.product.unique_identifier}-#{ship_line.get_custom_value(size_custom_def).value}",
          :hts_code=>tariff.hts_code,
          :description=>entry.merchandise_description,
          :unit_of_measure=>"EA",
          :quantity=>ship_line.quantity,
          :unit_price => tariff.entered_value / total_units,
          :rate => tariff.duty_amount / tariff.entered_value,
          :compute_code => "7",
          :ocean => entry.ocean?
        )
        d.duty_per_unit = d.unit_price * d.rate
        d.save!
        ps.update_attributes(:drawback_import_line_id=>d.id)
        r << d
      end
      r
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
end

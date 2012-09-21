module OpenChain
  class DrawbackProcessor
    
    DOZENS_LABELS = ["DOZ","DPR"]
    # Link entries to shipments and create drawback import lines, writing change records for each commercial invoice line
    def self.process_entries entries
      processor = self.new
      entries.each do |entry|
        entry.commercial_invoice_lines.each do |ci|
          cr = ci.change_records.build
          linked = processor.link_commercial_invoice_line ci, cr
          if linked.empty?
            cr.add_message "Line wasn't matched to any shipments.", true
          else
            processor.make_drawback_import_lines ci, cr 
          end
          cr.save!
        end
      end
    end
    # Links a commercial invoice line to shipment lines if the commercial invoice line is not already linked and shipment line is not already linked
    # Takes an optional change record which should ve linked to the commercial invoice line. If it is not null, then messages will be added (but not saved) and the
    # failure flag will be set if no matches are made
    # Returns an array of ShipmentLines that were matched
    def link_commercial_invoice_line c_line, change_record=nil
      r = []
      entry = c_line.entry
      cr = change_record.nil? ? ChangeRecord.new : change_record #use a junk change record to make the rest of the coding easier if nil was passed
      unallocated_quantity = (c_line.quantity.nil? ? 0 : c_line.quantity) - c_line.piece_sets.where("shipment_line_id is not null").sum("piece_sets.quantity")
      if unallocated_quantity <= 0
        cr.add_message("Commercial Invoice Line is fully allocated to shipments.")
      else
        find_shipment_lines(c_line).each do |s_line|
          break if unallocated_quantity == 0
          shipment_line_unallocated = s_line.quantity - s_line.piece_sets.where("commercial_invoice_line_id is not null").sum("piece_sets.quantity")
          next if shipment_line_unallocated <= 0
          if shipment_line_unallocated >= unallocated_quantity
            c_line.piece_sets.create!(:shipment_line_id=>s_line.id,:quantity=>unallocated_quantity)
            cr.add_message("Matched to Shipment: #{s_line.shipment.reference}, Line: #{s_line.line_number}, Quantity: #{unallocated_quantity}")
            r << s_line
            break
          else
            c_line.piece_sets.create!(:shipment_line_id=>s_line.id,:quantity=>shipment_line_unallocated)
            cr.add_message("Matched to Shipment: #{s_line.shipment.reference}, Line: #{s_line.line_number}, Quantity: #{shipment_line_unallocated}")
            unallocated_quantity -= shipment_line_unallocated
            r << s_line
          end
        end
      end
      r
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
      entry = c_line.entry
      tariff = c_line.commercial_invoice_tariffs.first #Under Armour will only have one
      [
        [(tariff.entered_value==0),"Cannot make line because entered value is 0."],
        [(tariff.entered_value.nil?),"Cannot make line because entered value is empty."],
        [(tariff.duty_amount.nil?),"Cannot make line because duty amount is empty."],
      ].each do |x|
        if x[0]
          cr.add_message x[1], true
          return r
        end
      end
      piece_sets.each do |ps|
        ship_line = ps.shipment_line
        shipment = ship_line.shipment
        d = DrawbackImportLine.new(:entry_number=>entry.entry_number,
          :import_date=>entry.arrival_date,
          :received_date=>get_received_date(shipment),
          :port_code=>entry.entry_port_code,
          :box_37_duty => entry.total_duty,
          :box_40_duty => entry.total_duty_direct,
          :country_of_origin_code => get_country_of_origin(ship_line,c_line),
          :product_id => ship_line.product_id,
          :part_number=> get_part_number(ship_line,c_line),
          :hts_code=>tariff.hts_code,
          :description=>entry.merchandise_description,
          :unit_of_measure=>"EA",
          :quantity=>ps.quantity,
          :unit_price => tariff.entered_value / c_line.quantity,
          :rate => tariff.duty_amount / tariff.entered_value,
          :compute_code => "7",
          :ocean => entry.ocean?,
          :total_mpf => entry.mpf,
          :importer_id => entry.importer_id
        )
        d.duty_per_unit = d.unit_price * d.rate
        d.save!
        ps.update_attributes(:drawback_import_line_id=>d.id)
        cr.add_message "Drawback Import Line created successfully. (DB ID: #{d.id})"
        r << d
      end
      r
    end
  end
end

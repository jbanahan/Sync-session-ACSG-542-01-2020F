require 'open_chain/drawback_processor'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; class JCrewDrawbackProcessor < OpenChain::DrawbackProcessor
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  
  def self.process_date_range arrival_date_start, arrival_date_end, user=nil
    ['J0000','JCREW'].each do |cnum|
      imp = Company.with_customs_management_number(cnum).first
      self.process_entries Entry.where(importer_id:imp.id).where('entries.arrival_date between ? and ?',arrival_date_start,arrival_date_end)
    end
    if user
      u = user.is_a?(Numeric) ? User.where(user_id: user).first : user
      u.messages.create!(body:"J Crew drawback processing complete for date range #{arrival_date_start} - #{arrival_date_end}",subject:'J Crew Drawback Processing Complete')
    end
  end

  def find_shipment_lines commercial_invoice_line
    entry = commercial_invoice_line.entry
    po_search = SearchCriterion.new(:model_field_uid=>cdefs[:shpln_po].model_field_uid,:operator=>"eq",:value=>commercial_invoice_line.po_number)
    received_date_search = SearchCriterion.new(:model_field_uid=>cdefs[:shp_delivery_date].model_field_uid,:operator=>'gt',:value=>entry.arrival_date-1.day)
    received_date_search.apply po_search.apply ShipmentLine.select("shipment_lines.*").joins(:shipment).joins(:product).where("products.unique_identifier = ?","JCREW-#{commercial_invoice_line.part_number}").
      where("shipments.importer_id = ? OR shipments.importer_id IN (SELECT parent_id FROM linked_companies WHERE child_id = ?)",entry.importer_id,entry.importer_id).
      where("shipments.reference = ?",entry.entry_number)
  end

  def get_received_date(shipment_line)
    shipment_line.shipment.custom_value(cdefs[:shp_delivery_date])
  end
  
  def get_country_of_origin(shipment_line, commercial_invoice_line) 
    commercial_invoice_line.country_origin_code
  end

  def get_part_number s_line, c_line
    "#{c_line.part_number}#{s_line.custom_value(cdefs[:shpln_color])}#{s_line.custom_value(cdefs[:shpln_size])}"
  end

  private

    def cdefs
      @cdefs ||= self.class.prep_custom_definitions([:shpln_po, :shp_delivery_date, :shpln_color, :shpln_size])
    end
  
end; end

require 'open_chain/drawback_processor'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Crocs
  class CrocsDrawbackProcessor < OpenChain::DrawbackProcessor
    include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

    def self.process_entries_by_arrival_date start_date, end_date
      process_entries Entry.
        where('arrival_date >= ?',start_date.to_date).
        where('arrival_date <= ?',end_date.to_date).
        where('importer_id = ?',Company.find_by_alliance_customer_number('CROCS').id)
    end

    def find_shipment_lines ci_line
      prep_custom_defs
      return [] if ci_line.part_number.blank? || ci_line.po_number.blank?
      clean_po = format_po_number ci_line.po_number
      return [] if clean_po.nil?
      imp_date = ci_line.entry.arrival_date
      return [] if imp_date.nil?
      imp_date_str = imp_date.strftime('%Y-%m-%d')
      ShipmentLine.select('shipment_lines.*').joins("
        INNER JOIN shipments on shipment_lines.shipment_id = shipments.id AND shipments.importer_id = (SELECT id FROM companies WHERE alliance_customer_number = 'CROCS')
        INNER JOIN products p on shipment_lines.product_id = p.id AND p.unique_identifier = 'CROCS-#{ci_line.part_number.strip}'
        INNER JOIN custom_values po on po.custom_definition_id = #{@defs[:shpln_po].id} AND po.customizable_id = shipment_lines.id AND po.string_value REGEXP '^0#{clean_po}'
        INNER JOIN custom_values rec on rec.custom_definition_id = #{@defs[:shpln_received_date].id} and rec.customizable_id = shipment_lines.id AND rec.date_value >= '#{imp_date_str}' AND rec.date_value < ADDDATE('#{imp_date_str}',61)
        INNER JOIN custom_values coo on coo.custom_definition_id = #{@defs[:shpln_coo].id} AND coo.customizable_id = shipment_lines.id AND coo.string_value = '#{ci_line.country_origin_code}'
      ")
    end

    def get_part_number s_line, ci_line
      prep_custom_defs
      "#{s_line.get_custom_value(@defs[:shpln_sku]).value}-#{s_line.get_custom_value(@defs[:shpln_coo]).value}"
    end

    def get_country_of_origin s_line, ci_line
      prep_custom_defs
      s_line.get_custom_value(@defs[:shpln_coo]).value
    end

    def get_received_date s_line
      prep_custom_defs
      s_line.get_custom_value(@defs[:shpln_received_date]).value
    end
  
    #find the 7 digit base PO number fromt the commercial invoice PO number
    def format_po_number base_po
      return base_po if base_po.match /^[[:digit:]]{7}$/
      po = base_po.strip.gsub(/[^a-zA-Z0-9]/,'') #clear non alphanumerics
      return po[3,7] if po.match /^[a-zA-Z]{3}[0-9]{7}$/ #country prefix format
      o_idx = po.index('O')
      return po[o_idx-7,7] if o_idx && o_idx>=7 #warehouse formats
      nil
    end

    private
    def prep_custom_defs
      @defs ||= self.class.prep_custom_definitions [:shpln_po,:shpln_received_date,:shpln_coo,:shpln_sku]
    end
  end
end; end; end

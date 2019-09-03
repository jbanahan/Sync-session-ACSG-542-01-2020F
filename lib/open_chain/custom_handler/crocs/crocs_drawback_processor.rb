require 'open_chain/drawback_processor'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Crocs
  class CrocsDrawbackProcessor < OpenChain::DrawbackProcessor
    include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

    def self.process_entries_by_arrival_date start_date, end_date
      process_entries Entry.
        where('arrival_date >= ?',start_date.to_date).
        where('arrival_date <= ?',end_date.to_date).
        where('importer_id = ?', crocs_id)
    end

    def find_shipment_lines ci_line
      prep_custom_defs
      return [] if ci_line.part_number.blank? || ci_line.po_number.blank?
      clean_po = format_po_number ci_line.po_number
      return [] if clean_po.nil?
      imp_date = ci_line.entry.arrival_date
      return [] if imp_date.nil?
      imp_date_str = imp_date.strftime('%Y-%m-%d')
      joins_query = ActiveRecord::Base.sanitize_sql_array(["INNER JOIN shipments on shipment_lines.shipment_id = shipments.id AND shipments.importer_id = ?
        INNER JOIN products p on shipment_lines.product_id = p.id AND p.unique_identifier = ?
        INNER JOIN custom_values po on po.custom_definition_id = #{@defs[:shpln_po].id.to_i} AND po.customizable_id = shipment_lines.id AND po.string_value REGEXP ?
        INNER JOIN custom_values rec on rec.custom_definition_id = #{@defs[:shpln_received_date].id.to_i} and rec.customizable_id = shipment_lines.id AND rec.date_value >= ? AND rec.date_value < ADDDATE(?,61)
        INNER JOIN custom_values coo on coo.custom_definition_id = #{@defs[:shpln_coo].id.to_i} AND coo.customizable_id = shipment_lines.id AND coo.string_value = ? 
      ", self.class.crocs_id.to_i, "CROCS-#{ci_line.part_number.strip}", "^0#{clean_po}", imp_date_str, imp_date_str, ci_line.country_origin_code])

      ShipmentLine.select('shipment_lines.*').joins(joins_query)
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

    def self.crocs_id
      Company.with_customs_management_number('CROCS').first&.id
    end

    private
    def prep_custom_defs
      @defs ||= self.class.prep_custom_definitions [:shpln_po,:shpln_received_date,:shpln_coo,:shpln_sku]
    end

    def crocs_id
      @id ||= self.class.crocs_id
    end
  end
end; end; end

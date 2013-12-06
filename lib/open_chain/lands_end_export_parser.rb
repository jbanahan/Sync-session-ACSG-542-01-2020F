require 'open_chain/drawback_export_parser'
module OpenChain
  class LandsEndExportParser < DrawbackExportParser
    def self.parse_csv_line r, row_number, importer
      us = Country.find_by_iso_code 'US'
      hts_map = {}
      d = DutyCalcExportFileLine.new
      return nil if r.size <= 1 && r[0].blank?
      raise "Line #{row_number} had #{r.size} elements.  All lines must have 29 elements." unless r.size==29
      raise "Line #{row_number} is missing the part number." if r[12].blank?
      hts_code = r[9].gsub('.','')
      hts_map[hts_code[0,4]] ||= get_description(hts_code[0,4],us)
      d.export_date = d.ship_date = Date.strptime(r[1],"%m/%d/%Y")
      d.part_number = r[12]
      d.ref_1 = r[7]
      d.ref_2 = r[0]
      d.destination_country = "CA"
      d.quantity = r[13] 
      d.description = hts_map[hts_code[0,4]]
      d.uom = "EA"
      d.exporter = "Lands End"
      d.action_code = "E"
      d.hts_code = hts_code
      d.importer = importer
      d
    end
    private
    def self.get_description hts_prefix, us
      ot = OfficialTariff.where(:country_id=>us.id).where("hts_code like ?","#{hts_prefix}%").first
      r = ot.nil? ? "Unlisted Item" : ot.chapter
      r = r[0,r.index(/[,;]/)] if r.match(/[,;]/)
    end
  end
end

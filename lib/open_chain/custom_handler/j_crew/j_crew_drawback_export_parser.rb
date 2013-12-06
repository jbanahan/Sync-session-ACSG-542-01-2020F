require 'open_chain/drawback_export_parser'
module OpenChain; module CustomHandler; module JCrew
  class JCrewDrawbackExportParser < OpenChain::DrawbackExportParser
    def self.parse_csv_line r, row_number, importer
      return nil if r.size <= 1 && r[0].blank? # stray rows
      raise "Line #{row_number} had #{r.size} elements.  All lines must have 167 elements." unless r.size==167
      return nil if r[121].blank? || r[121] == '0'
      d = DutyCalcExportFileLine.new
      d.ship_date = Date.strptime(r[105],'%m/%d/%Y')
      d.export_date = Date.strptime(r[106],'%m/%d/%Y')
      d.part_number = r[164]
      d.ref_1 = r[116]
      d.ref_2 = r[8]
      d.destination_country = 'CA'
      d.quantity = r[121]
      d.description = r[122]
      d.uom = 'EA'
      d.exporter = 'J Crew'
      d.action_code = 'E'
      d.hts_code = r[120]
      d.importer = importer
      d
    end
  end
end; end; end

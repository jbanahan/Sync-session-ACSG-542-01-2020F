require 'open_chain/drawback_export_parser'
module OpenChain
  module CustomHandler
    module Crocs
      class CrocsDrawbackExportParser < OpenChain::DrawbackExportParser
        def self.parse_csv_line r, row_num, importer
          return nil if r.size <= 1 && r[0].blank?
          raise "Line #{row_num} had #{r.size} elements.  All lines must have 19 elements." unless r.size==19
          d = DutyCalcExportFileLine.new
          d.export_date = Date.strptime(r[3],"%m-%d-%Y")
          d.ship_date = d.export_date
          d.importer = importer
          d.part_number = r[11]
          d.carrier = r[17]
          d.ref_1 = r[0]
          d.ref_2 = r[1]
          d.ref_3 = r[2]
          d.destination_country = r[10]
          d.quantity = r[14]
          d.description = r[12]
          d.uom = r[15]
          d.exporter = 'Crocs'
          d.action_code = 'E'
          d
        end
      end
    end
  end
end

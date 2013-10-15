require 'open_chain/drawback_export_parser'
module OpenChain
  module CustomHandler
    module Crocs
      class CrocsDrawbackExportParser < OpenChain::DrawbackExportParser
        def self.parse_csv_line r, row_num, importer
          return nil if r.size <= 1 && r[0].blank?
          raise "Line #{row_num} had #{r.size} elements.  All lines must have 18 elements." unless r.size==18
          return nil unless r[15]=='Pairs'
          exp_d = r[3].split('/')
          exp_d[2] = "20#{exp_d[2]}" if(exp_d[2].length==2)
          d = DutyCalcExportFileLine.new
          d.export_date = Date.new(exp_d[2].to_i,exp_d[0].to_i,exp_d[1].to_i)
          d.ship_date = d.export_date
          d.importer = importer
          d.part_number = "#{r[11]}-#{r[13]}"
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

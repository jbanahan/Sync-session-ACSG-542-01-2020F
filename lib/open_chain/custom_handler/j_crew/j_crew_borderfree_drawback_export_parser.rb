require 'open_chain/drawback_export_parser'
require 'open_chain/tariff_finder'
module OpenChain; module CustomHandler; module JCrew
  class JCrewBorderfreeDrawbackExportParser < OpenChain::DrawbackExportParser
    def self.parse_csv_line r, row_number, importer
      return nil if r.size <= 1 && r[0].blank? # stray rows

      # I believe this should be 17 no matter what.  Double check?
      raise "Line #{row_number} had #{r.size} elements.  All lines must have 17 elements." unless r.size==17
      quanity = 
      d = DutyCalcExportFileLine.new
      d.ship_date = DateTime.strptime(r[2], "%m/%d/%Y %H:%M:%S %p")
      d.export_date = DateTime.strptime(r[2], "%m/%d/%Y %H:%M:%S %p")
      d.part_number = get_part_number(r[12]) #function on column m
      d.ref_1 = r[4] #column e
      d.ref_2 = r[6] #column g
      d.ref_3 = 'BorderFree'
      d.carrier = r[5] #column f
      d.destination_country = r[8] #column i
      d.quantity = r[15] #column p
      d.description = r[11] #column l
      d.uom = r[16] #column q
      d.exporter = 'J Crew'
      d.action_code = 'E'
      d.hts_code = OpenChain::TariffFinder.new(Country.find_by_iso_code("US"), Company.where(alliance_customer_number: ['J0000','JCREW'].to_a)).find_by_style(d.part_number)
      d.importer = importer
      d
    end

    def self.get_part_number str
      x = str.split(' - ')
      raise "Bad Part number in #{str}" if (x.blank? || x.length==1)
      r = x[1].split(' ').first
      raise "Bad part number in #{r}" unless r.match(/^\w{5}/)
      r
    end
  end
end; end; end

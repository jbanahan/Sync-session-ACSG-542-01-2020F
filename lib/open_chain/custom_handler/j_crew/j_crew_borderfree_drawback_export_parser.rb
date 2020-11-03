require 'open_chain/drawback_export_parser'
require 'open_chain/tariff_finder'
module OpenChain; module CustomHandler; module JCrew
  class JCrewBorderfreeDrawbackExportParser < OpenChain::DrawbackExportParser
    def self.parse_csv_line r, row_number, importer
      return nil if r.size <= 1 && r[0].blank? # stray rows

      # I believe this should be 17 no matter what.  Double check?
      raise "Line #{row_number} had #{r.size} elements.  All lines must have 17 elements." unless r.size == 17
      d = DutyCalcExportFileLine.new
      d.ship_date = parse_date(r[2])
      d.export_date = d.ship_date
      d.part_number = get_part_number(r[12]) # function on column m
      d.ref_1 = r[4] # column e
      d.ref_2 = r[6] # column g
      d.ref_3 = 'BorderFree'
      d.carrier = r[5] # column f
      d.destination_country = r[8] # column i
      d.quantity = r[15] # column p
      d.description = r[11] # column l
      d.uom = r[16] # column q
      d.exporter = 'J Crew'
      d.action_code = 'E'
      d.hts_code = OpenChain::TariffFinder.new("US", Company.with_customs_management_number(['J0000', 'JCREW']).to_a).by_style(d.part_number)
      d.importer = importer
      d
    end

    def self.get_part_number str
      x = str.split(' - ')
      raise "Bad Part number in #{str}" if x.blank? || x.length == 1
      r = x[1].split(' ').first
      raise "Bad part number in #{r}" unless r.match(/^\w{5}/)
      r
    end

    def self.csv_column_separator line
      ["|", "\t"].each do |ch|
        return ch if line.split(ch).length == 17
      end
      ','
    end

    def self.parse_date str
      date_format = case str.split(' ')
                    when 3
        "%m/%d/%Y %i:%M:%S %p"
                    when 2
        "%m/%d/%Y %H:%M:%S"
                    else
        "%m/%d/%Y"
      end
      DateTime.strptime(str, date_format)
    end
  end
end; end; end

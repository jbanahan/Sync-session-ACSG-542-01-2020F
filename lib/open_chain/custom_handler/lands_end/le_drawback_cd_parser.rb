module OpenChain
  module CustomHandler
    module LandsEnd
      # Process Lands End Certificate of Delivery file from Fed Ex after reformatting into CSV with headers like:
      #
      # [ignore],Entry Number,[ignore],[ignore],[ignore],Part - Description,[ignore],[ignore],[ignore],100% Duty Per Unit
      class LeDrawbackCdParser
        def initialize lands_end_company
          @company = lands_end_company
        end

        def parse data
          CSV.parse(data,headers:true) do |row|
            next if row.blank?
            duty_per_unit = BigDecimal(row[9],2) / BigDecimal(row[6],2)
            h = {
              entry_number:row[1],
              part_number:row[5].split('-').first.strip,
              duty_per_unit:duty_per_unit
            }
            KeyJsonItem.lands_end_cd("#{h[:entry_number]}-#{h[:part_number]}").first_or_create!(json_data:h.to_json)
            DrawbackImportLine.where(importer_id:@company.id,entry_number:h[:entry_number],part_number:h[:part_number]).update_all(h)
          end
        end
      end
    end
  end
end

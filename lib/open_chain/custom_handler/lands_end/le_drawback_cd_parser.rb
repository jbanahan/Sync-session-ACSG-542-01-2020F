module OpenChain
  module CustomHandler
    module LandsEnd
      class LeDrawbackCdParser
        def initialize lands_end_company
          @company = lands_end_company
        end

        def parse data
          CSV.parse(data,headers:true) do |row|
            h = {
              entry_number:row[1],
              part_number:row[5].split('-').first.strip,
              duty_per_unit:row[9]
            }
            KeyJsonItem.lands_end_cd("#{h[:entry_number]}-#{h[:part_number]}").first_or_create!(json_data:h.to_json)
            DrawbackImportLine.where(importer_id:@company.id,entry_number:h[:entry_number],part_number:h[:part_number]).update_all(h)
          end
        end
        private
      end
    end
  end
end

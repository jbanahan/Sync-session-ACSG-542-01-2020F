module OpenChain
  module CustomHandler
    module LandsEnd
      # THIS PARSER CAN ONLY BE CALLED ONCE PER FILE!!!
      #
      # It increments quantities, so calling multiple times will put too much data in the drawback database
      #
      # This is based on a CSV created from the Import By Entry report from FedEx which must be reformatted to match the layout below
      #
      # Entry Number, Port Code, Import Date, Received Date, HTS Code, Part - Description, Quantity, UOM, Unit Price, Duty Rate
      class LeDrawbackImportParser
        def initialize lands_end_company
          @company = lands_end_company
        end

        def parse data
          #this all has to be in a long running transaction because if there's an error, 
          #we've incremented values which MUST be undone for the whole file so it can be
          #reprocessed
          ActiveRecord::Base.transaction do
            CSV.parse(data,headers:true) do |row|
              next if row.blank?
              part_number = row[5].split('-').first.strip
              q = DrawbackImportLine.where(importer_id:@company.id,
                entry_number:row[0],part_number:part_number)
              d = q.first_or_create!(
                product_id:Product.where(unique_identifier:"LANDSEND-#{part_number}").first_or_create!.id,
                description:description(row[5]),
                port_code:row[1],
                import_date:format_date(row[2]),
                received_date:format_date(row[3]),
                hts_code:row[4],
                quantity:0,
                unit_of_measure:row[7],
                unit_price:row[8].gsub('$',''),
                rate:( BigDecimal(row[9].gsub('%',''))*BigDecimal('0.01') )
              )
              d.quantity += BigDecimal(row[6])
              key = "#{d.entry_number}-#{d.part_number}"
              kj = KeyJsonItem.lands_end_cd(key).first
              d.duty_per_unit = kj.data['duty_per_unit'] if kj
              d.save!
            end
          end
        end

        private
        def description raw
          dash = raw.index('-')
          raw[dash+2,raw.length - dash+2]
        end
        def format_date d
          Date.new(d.split('/').last.to_i,
            d.split('/').first.to_i,
            d.split('/')[1].to_i).strftime("%Y%m%d")
        end
      end
    end
  end
end

module OpenChain
  module CustomHandler
    class JCrewShipmentParser
      def self.parse_merged_entry_file file_path
        parse_merged_entry_data IO.read file_path
      end
      def self.parse_merged_entry_data file_data
        importer_hash = {'JCREW'=>Company.find_by_alliance_customer_number('JCREW'),'J0000'=>Company.find_by_alliance_customer_number('J0000')}
        custom_def_hash = {'dd'=>CustomDefinition.find_or_create_by_label_and_module_type('Delivery Date','Shipment',:data_type=>'date'),
          'po' => CustomDefinition.find_or_create_by_label_and_module_type('PO Number','ShipmentLine',:data_type=>'string'),
          'cl' => CustomDefinition.find_or_create_by_label_and_module_type('Color','ShipmentLine',:data_type=>'string'),
          'sz' => CustomDefinition.find_or_create_by_label_and_module_type('Size','ShipmentLine',:data_type=>'string')
        }
        crew_vendor = Company.find_or_create_by_name("JCREW Vendor",:vendor=>true)
        lines = []
        current_entry = ''
        CSV.parse(file_data,:headers=>true) do |row|
          entry_number = row[2]
          if entry_number!=current_entry && !lines.empty?
            parse_merged_entry_data_rows lines, importer_hash, custom_def_hash, crew_vendor
            lines = []
          end
          current_entry = entry_number
          lines << row
        end
        parse_merged_entry_data_rows lines, importer_hash, custom_def_hash, crew_vendor unless lines.empty?
        return true
      end

      private 
      def self.parse_merged_entry_data_rows rows, importer_hash, custom_def_hash, vendor
        first_row = rows[0]
        s = Shipment.find_or_create_by_importer_id_and_reference(importer_hash[first_row[1]].id, first_row[2], :vendor_id=>vendor.id)
        dd_sp = first_row[3].split('/')
        s.update_custom_value! custom_def_hash['dd'], Date.new(dd_sp.last.to_i,dd_sp.first.to_i,dd_sp[1].to_i)
        s.shipment_lines.destroy_all
        rows.each do |r|
          next if r[8].blank?
          sl = s.shipment_lines.create!(:product_id=>Product.find_or_create_by_unique_identifier(r[8]).id,:quantity=>r[12])
          sl.update_custom_value! custom_def_hash['po'], r[7]
          sl.update_custom_value! custom_def_hash['cl'], r[9]
          sl.update_custom_value! custom_def_hash['sz'], (r[11].blank? ? r[10] : "#{r[10]}/#{r[11]}")
        end
      end
    end
  end
end

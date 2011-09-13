module OpenChain
  module Report
    class TariffComparison
      
      # Run the report
      # settings = {'old_tariff_set_id'=>1,'new_tariff_set_id'=>2}
      def self.run_report run_by, settings
        raise "Two tariff sets are required." unless settings['old_tariff_set_id'] && settings['new_tariff_set_id']
        old_ts = TariffSet.find settings['old_tariff_set_id']
        new_ts = TariffSet.find settings['new_tariff_set_id']
        raise "Both tariff sets must be from the same country." unless old_ts.country_id == new_ts.country_id
        TariffComparison.run old_ts, new_ts
      end

      private
      def self.run old_tariff_set, new_tariff_set
        added, removed, changed = new_tariff_set.compare old_tariff_set

        wb = Spreadsheet::Workbook.new

        a_sheet = wb.create_worksheet :name=>"Added"
        make_list_sheet a_sheet, added

        r_sheet = wb.create_worksheet :name=>"Removed"
        make_list_sheet r_sheet, removed

        c_sheet = wb.create_worksheet :name=>"Changed"
        c_row = 0
        changed.keys.each do |hts|
          r = c_sheet.row c_row
          r.push "HTS"
          r.push unfreeze(hts)
          c_row += 1
          r = c_sheet.row c_row
          r.push ""
          r.push "Attribute"
          r.push "New Value"
          r.push "Old Value"
          c_row += 1
          new_hash, old_hash = changed[hts]
          new_hash.keys.each do |a|
            r = c_sheet.row c_row
            r.push ""
            r.push unfreeze(a)
            r.push unfreeze(new_hash[a])
            r.push unfreeze(old_hash[a])
            c_row += 1
          end
          c_row += 1
          
        end

        t = Tempfile.new ['tariff_comparison','.xls']
        wb.write t.path 
        t
      end

      private

      def self.unfreeze str
        str.frozen? ? str.dup : str
      end

      def self.make_list_sheet sheet, collection
        heading_row = sheet.row 0
        labels = ["HTS Code","Description","General Rate","Special Rates","Erga Omnes Rate","MFN Rate",
          "GPT Rate","Ad Valorem Rate","Per Unit Rate",
          "Calculation Method","UOM","Column 2 Rate","Import Regulations",
          "Export Regulations"]
        labels.each do |lbl|
          heading_row.push lbl  
        end

        collection.each_with_index do |t,i|
          r = sheet.row i+1
          r.push t.hts_code
          r.push t.full_description
          r.push t.general_rate
          r.push t.special_rates
          r.push t.erga_omnes_rate
          r.push t.most_favored_nation_rate
          r.push t.general_preferential_tariff_rate
          r.push t.add_valorem_rate
          r.push t.per_unit_rate
          r.push t.calculation_method
          r.push t.unit_of_measure
          r.push t.column_2_rate
          r.push t.import_regulations
          r.push t.export_regulations
        end
      end
    end
  end
end

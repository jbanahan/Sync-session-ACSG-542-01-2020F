require 'open_chain/xl_client'
module OpenChain
  module CustomHandler
    class PoloCaEntryParser
      POLO_IMPORTER_TAX_IDS = ['806167003RM0001','871349163RM0001','866806458RM0001']
      def initialize(custom_file)
        @custom_file = custom_file
        @canada = Country.find_by_iso_code 'CA' 
      end

      def can_view?(user)
        user.company.master? && user.edit_entries?
      end

      def process(user)
        row_counter = 1
        raise "User does not have permission to process these entries." if !user.edit_entries? || !user.company.master?
        xlc = XLClient.new(@custom_file.attached.path)
        last_row = xlc.last_row_number(0)
        begin
          (1..last_row).each do |n|
            row_counter = n
            row = xlc.get_row 0, n
            val_hash = {}
            row.each do |cell|
              val_hash[cell['position']['column']] = cell['cell']['value']
            end
            parse_record :brok_ref=>fix_numeric(val_hash[0]),
              :mbol=>fix_numeric(val_hash[1]),
              :hbol=>fix_numeric(val_hash[2]),
              :cont=>fix_numeric(val_hash[3]),
              :docs_rec=>val_hash[5]
          end
        rescue
          $!.log_me ["Custom File ID: #{@custom_file.id}","Row: #{row_counter}"]
          raise $!
        end
        user.messages.create(:subject=>"Polo Canada Worksheet Complete",:body=>"Your Polo Canada worksheet job has completed. You can download the updated file <a href='/custom_features/polo_canada'>here</a>.")
      end

      #not private for unit testing purposes only
      def parse_record vals
        return if vals[:brok_ref].blank?
        ent = Entry.where(:broker_reference=>vals[:brok_ref].strip,:source_system=>'Fenix').first
        if ent && !ent.importer_tax_id.blank? && !POLO_IMPORTER_TAX_IDS.include?(ent.importer_tax_id)
          raise "Broker Reference #{vals[:brok_ref]} is not assigned to a Ralph Lauren importer."
        end
        changed = false
        if ent.nil?
          ent = Entry.new(:broker_reference=>vals[:brok_ref].strip,:source_system=>'Fenix',:import_country_id=>@canada.id)
          changed = true
        end
        changed = true if update_if_changed(ent,:master_bills_of_lading,clean_csv_lists(vals[:mbol]))
        changed = true if update_if_changed(ent,:house_bills_of_lading,clean_csv_lists(vals[:hbol]))
        changed = true if update_if_changed(ent,:container_numbers,clean_csv_lists(vals[:cont]))
        changed = true if update_if_changed(ent,:docs_received_date,vals[:docs_rec])
        if changed
          ent.save! 
          @custom_file.custom_file_records.create!(:linked_object=>ent)
        end
      end
      
      private
      def clean_csv_lists hash_val
        return '' if hash_val.blank?
        hash_val.split(',').collect {|v| v.strip}.join(' ')
      end
      def update_if_changed entry, field_name, hash_val
        changed = false
        return changed if hash_val.blank?
        if hash_val.respond_to?(:strftime)
          if entry[field_name].blank? || entry[field_name].strftime("%Y%m%d") != hash_val.strftime("%Y%m%d")
            changed = true
          end
        elsif entry[field_name] != hash_val
          changed = true
        end
        entry[field_name] = hash_val if changed
        changed
      end
      def fix_numeric val
        return '' if val.blank?
        v = val.to_s
        v = v[0,v.size-2] if v.end_with?('.0')
        v
      end
    end
  end
end

require 'open_chain/xl_client'
module OpenChain
  module CustomHandler
    # Updates CSM number for existing styles based on spreadsheet sent from team in Italy
    class PoloCsmSyncHandler
      def initialize(custom_file)
        @custom_file = custom_file
        @csm_cd = CustomDefinition.find_or_create_by_label("CSM Number",:module_type=>'Product',:data_type=>'string')
      end

      def process user, first_row = 1
        italy = Country.find_by_iso_code "IT"
        us = Country.find_by_iso_code "US"
        xlc = XLClient.new(@custom_file.attached.path)
        last_row = xlc.last_row_number(0)
        begin
          (first_row..last_row).each do |n|
            matched = 'Style Not Found'
            style = xlc.get_cell(0, n, 8)['cell']['value']
            next if style.blank?
            style = style.to_s
            style.strip!
            style = style[0,style.size-2] if style.end_with? '.0' #fix accidental numerics
            p = Product.includes(:classifications=>:tariff_records).where(:unique_identifier=>style).first
            unless p.blank?
              raise "User does not have permission to edit product #{p.unique_identifier}" unless p.can_edit? user
              matched = 'Style Found, No US / IT HTS'
              csm_number = string_val(xlc,0,n,2) + string_val(xlc,0,n,3) + string_val(xlc,0,n,4)
              p.update_custom_value! @csm_cd, csm_number
              p.create_snapshot user
              italy_classification = p.classifications.find_by_country_id italy.id
              if italy_classification
                tr = italy_classification.tariff_records.first
                matched = 'Style Found with IT HTS' if tr && !tr.hts_1.blank?
              else
                us_classification = p.classifications.find_by_country_id(us.id)
                if us_classification && us_classification.tariff_records.first && !us_classification.tariff_records.first.hts_1.blank?
                  matched = 'Style Found, No IT HTS'
                end
              end
            end
            xlc.set_cell 0, n, 16, matched
          end
          xlc.save
        rescue
          xlc.save
          $!.log_me ["Custom File ID: #{@custom_file.id}","Last Row: #{last_row}"]
          raise $! if $!.message.include?("User does not have permission to edit product")
        end
        user.messages.create(:subject=>"CSM Sync Complete",:body=>"Your CSM Sync job has completed.  You can download the updated file <a href='/custom_features/csm_sync'>here</a>.")
      end
      private
      def string_val xlc, sheet, row, cell
        r = xlc.get_cell(sheet,row,cell)['cell']['value']
        return r if r.nil?
        r = r[0,r.size-2] if r.end_with? '.0' #fix numerics
        r
      end
    end
  end
end

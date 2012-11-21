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
        had_errors = false
        italy = Country.find_by_iso_code "IT"
        us = Country.find_by_iso_code "US"
        xlc = XLClient.new(@custom_file.attached.path)
        xlc.raise_errors = true
        last_row = xlc.last_row_number(0)
        begin
          (first_row..last_row).each do |n|
            begin
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
                csm_custom_val = p.get_custom_value @csm_cd
                if csm_custom_val.value != csm_number
                  csm_custom_val.value = csm_number
                  csm_custom_val.save!
                  p.create_snapshot user
                end
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
            rescue
              had_errors = true
              xlc.set_cell 0, n, 16, "Error. Contact support."
              $!.log_me ["Custom File ID: #{@custom_file.id}","Last Row: #{last_row}"]
            end
          end
          xlc.save
        rescue
          had_errors = true
          xlc.save
          $!.log_me ["Custom File ID: #{@custom_file.id}","Last Row: #{last_row}"]
          raise $! if $!.message.include?("User does not have permission to edit product")
        end
        if had_errors
          user.messages.create(:subject=>"CSM Sync Complete with Errors",:body=>"<p>Your CSM Sync job has completed.  You can download the updated file <a href='/custom_features/csm_sync'>here</a>.</p><p>Support has received notification regarding the errors in your file and will be researching them.</p>")
        else
          user.messages.create(:subject=>"CSM Sync Complete",:body=>"Your CSM Sync job has completed.  You can download the updated file <a href='/custom_features/csm_sync'>here</a>.")
        end
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

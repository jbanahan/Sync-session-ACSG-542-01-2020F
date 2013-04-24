require 'open_chain/xl_client'
module OpenChain
  module CustomHandler
    # Updates CSM number for existing styles based on spreadsheet sent from team in Italy
    class PoloCsmSyncHandler
      def initialize(custom_file,file_received_at=0.seconds.ago)
        @custom_file = custom_file
        @csm_cd = CustomDefinition.find_or_create_by_label("CSM Number",:module_type=>'Product',:data_type=>'text',:read_only=>true)
        @dept_cd = CustomDefinition.find_or_create_by_label("CSM Department",:module_type=>'Product',:data_type=>'text',:read_only=>true)
        @season_cd = CustomDefinition.find_or_create_by_label('CSM Season',:module_type=>'Product',:data_type=>'text',:read_only=>true)
        @first_csm_date_cd = CustomDefinition.find_or_create_by_label('CSM Received Date (First)',:module_type=>'Product',:data_type=>'date',:read_only=>true)  
        @last_csm_date_cd = CustomDefinition.find_or_create_by_label('CSM Received Date (Last)',:module_type=>'Product',:data_type=>'date',:read_only=>true)  
        @received_date = file_received_at 
      end

      def process user, first_row = 1
        had_errors = false
        current_style = ''
        begin
          xlc = XLClient.new(@custom_file.attached.path)
          xlc.raise_errors = true
          last_row = xlc.last_row_number(0)
          style_map = {}
          dept_map = {}
          season_map = {}
          (first_row..last_row).each do |n|
            row_hash = xlc.get_row_as_column_hash 0, n
            us_style_cell = row_hash[8]
            us_style = (us_style_cell.blank? || us_style_cell['value'].blank?) ? nil : us_style_cell['value']
            csm = get_csm_number row_hash
            next if csm.blank? || us_style.blank?
            raise "File failed: CSM Number at row #{n} was not 18 digits \"#{csm}\"" unless csm.size == 18

            style_map[us_style] ||= Set.new
            style_map[us_style] << csm

            department = row_hash[13]['value']
            dept_map[us_style] = department

            season_map[us_style] ||= Set.new
            season_map[us_style] << row_hash[0]['value']
          end
          style_map.each do |us_style,csm_set|
            current_style = us_style
            p = Product.where(:unique_identifier=>us_style).first_or_create!
            raise "File failed: #{user.full_name} can't edit product #{p.unique_identifier}" unless p.can_edit?(user)
            p.update_custom_value! @csm_cd, csm_set.to_a.join("\n")
            p.update_custom_value! @dept_cd, dept_map[us_style]
            update_season p, season_map[us_style]
            update_first_csm_date p
            update_last_csm_date p
          end
        rescue
          had_errors = true
          $!.log_me ["Custom File ID: #{@custom_file.id}","Style: #{current_style}"]
        end
        if had_errors
          user.messages.create(:subject=>"CSM Sync Complete with Errors",:body=>"<p>Your CSM Sync job has completed.  You can download the updated file <a href='/custom_features/csm_sync'>here</a>.</p><p>Support has received notification regarding the errors in your file and will be researching them.</p>")
        else
          user.messages.create(:subject=>"CSM Sync Complete",:body=>"Your CSM Sync job has completed.  You can download the updated file <a href='/custom_features/csm_sync'>here</a>.")
        end
      end
      private
      def get_csm_number row_hash
        r = ""
        (2..5).each do |i|
          cell_hash = row_hash[i]
          return nil unless cell_hash && cell_hash['value']
          r << string_val(cell_hash['value'])
        end
        r
      end
      def string_val val 
        r = val
        return r if r.nil?
        r = r[0,r.size-2] if r.end_with? '.0' #fix numerics
        r
      end
      def update_season product, season_set
        cv = product.get_custom_value @season_cd  
        current_vals = cv.value.blank? ? "" : cv.value
        current_vals.split("\n").each {|v| season_set << v} unless current_vals.blank?
        new_value = season_set.to_a.sort.join("\n")
        if new_value!=cv.value
          cv.value = new_value 
          cv.save!
        end
      end
      def update_first_csm_date product
        cv = product.get_custom_value @first_csm_date_cd
        if cv.value.blank?
          cv.value = @received_date 
          cv.save!
        end
      end
      def update_last_csm_date product
        cv = product.get_custom_value @last_csm_date_cd
        if cv.value.blank? || cv.value.to_datetime.to_i < @received_date.to_i
          cv.value = @received_date 
          cv.save!
        end
      end
    end
  end
end

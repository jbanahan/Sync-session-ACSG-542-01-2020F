require 'open_chain/xl_client'
module OpenChain
  module CustomHandler
    # Updates CSM number for existing styles based on spreadsheet sent from team in Italy
    class PoloCsmSyncHandler
      def initialize(custom_file,file_received_at=0.seconds.ago)
        @custom_file = custom_file
        @csm_cd = CustomDefinition.find_or_create_by_label("CSM Number",:module_type=>'Product',:data_type=>'text')
        @dept_cd = CustomDefinition.find_or_create_by_label("CSM Department",:module_type=>'Product',:data_type=>'text')
        @season_cd = CustomDefinition.find_or_create_by_label('CSM Season',:module_type=>'Product',:data_type=>'text')
        @first_csm_date_cd = CustomDefinition.find_or_create_by_label('CSM Received Date (First)',:module_type=>'Product',:data_type=>'date')  
        @last_csm_date_cd = CustomDefinition.find_or_create_by_label('CSM Received Date (Last)',:module_type=>'Product',:data_type=>'date')
        [@csm_cd,@dept_cd,@season_cd,@first_csm_date_cd,@last_csm_date_cd].each do |cd|
          fvr = FieldValidatorRule.where(custom_definition_id:cd.id,model_field_uid:"*cf_#{cd.id}",module_type:cd.module_type).first_or_create!(read_only:true)
          fvr.update_attributes(read_only:true) unless fvr.read_only?
        end
        @received_date = file_received_at 
      end

      def process user, first_row = 1
        system_errors = false
        current_style = ''
        csm_errors = []
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
            raise(CsmError, "File failed: CSM Number at row #{n} was not 18 digits \"#{csm}\"") unless csm.size == 18

            style_map[us_style] ||= Set.new
            style_map[us_style] << csm

            department = row_hash[13]['value']
            dept_map[us_style] = department

            season_map[us_style] ||= Set.new
            season_map[us_style] << row_hash[0]['value']
          end
          style_map.each do |us_style,csm_set|
            current_style = us_style
            begin
              Product.transaction do 
                p = Product.where(:unique_identifier=>us_style).first_or_create!
                raise(CsmError, "File failed: #{user.full_name} can't edit product #{p.unique_identifier}") unless p.can_edit?(user)
                p.update_custom_value! @csm_cd, csm_set.to_a.join("\n")
                p.update_custom_value! @dept_cd, dept_map[us_style]
                update_season p, season_map[us_style]
                update_first_csm_date p
                update_last_csm_date p

                OpenChain::FieldLogicValidator.validate!(p) 
              end
            rescue OpenChain::ValidationLogicError => e
              # Prefix the errors with the style so the user knows which one needs to be fixed
              if e.base_object.errors[:base]
                e.base_object.errors[:base].each do |err|
                  csm_errors << "Style: #{current_style} - #{err}"
                end
              end
            end
          end
        rescue CsmError => e
          # Since RL wants us to detect field validation errors, we're going to route those (above) and other logic issues
          # with the file into user messages that they will have to deal with themselves so we don't have to foward emails any longer.
          csm_errors << e.message
        rescue
          system_errors = true
          $!.log_me ["Custom File ID: #{@custom_file.id}","Style: #{current_style}"]
        end
         
        subject = "CSM Sync Complete"
        if system_errors || csm_errors.size > 0
          subject += " with Errors"
        end

        body = "<p>Your CSM Sync job has completed.  You can download the updated file <a href='/custom_features/csm_sync'>here</a>.</p>"
        if system_errors
          body += "<p>Support has received notification regarding system errors in your file and will be researching them.</p>"
        end

        if csm_errors.size > 0
          user_errors_message = ""
          csm_errors.each do |e|
            user_errors_message += "<li>#{e}</li>"
          end
          user_errors_message = "<p>The following CSM data errors were encountered:<ul>#{user_errors_message}</ul></p>"

          body += user_errors_message
        end

        user.messages.create(subject: subject, body: body)
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

      class CsmError < StandardError; end

    end
  end
end

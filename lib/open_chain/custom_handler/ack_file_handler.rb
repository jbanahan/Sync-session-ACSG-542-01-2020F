module OpenChain
  module CustomHandler
    # Process CSV Acknowledgements
    class AckFileHandler
      include IntegrationClientParser

      def parse file_contents, opts = {}
        raise ArgumentError, "Opts must have a :sync_code hash key." unless opts[:sync_code]
        raise ArgumentError, "Opts must have an s3 :key hash key." unless opts[:key]
        

        process_ack_file file_contents, File.basename(opts[:key]), opts[:sync_code], opts[:username], opts
      end
      
      def process_ack_file file_content, file_name, sync_code, username, opts={}
        un = username.blank? ? 'chainio_admin' : username
        errors = get_ack_file_errors file_content, file_name, sync_code, opts
        handle_errors errors, file_name, un, file_content, sync_code unless errors.blank?
      end

      def get_ack_file_errors file_content, file_name, sync_code, opts={}
        errors = []
        row_count = 0
        csv_opts = opts[:csv_opts] ? opts[:csv_opts] : {}
        StringIO.new(file_content).each do |line|
          row_count += 1
          next if row_count == 1
          row = CSV.parse_line line.strip, csv_opts
          errors << "Malformed response line: #{row.to_csv}" unless row.size==3
          prod = find_object row, opts
          if prod.nil?
            errors << "Product #{row[0]} confirmed, but it does not exist."
            next
          end
          sync = prod.sync_records.find_by_trading_partner sync_code 
          if sync.nil?
            errors << "Product #{row[0]} confirmed, but it was never sent."
            next
          end
          fail_message = row[2]=='OK' ? '' : row[2]
          sync.update_attributes(:confirmed_at=>Time.now,:confirmation_file_name=>file_name,:failure_message=>fail_message)
          errors << "Product #{row[0]} failed: #{fail_message}" unless fail_message.blank?
        end
        errors
      end

      # override this to do custom handling with the given array of error messages
      def handle_errors errors, file_name, username, file_content, sync_code
        messages = ["File Name: #{file_name}"]
        messages += errors

        email_address = User.find_by_username(username).email

        Tempfile.open(["temp",".csv"]) do |t|
          t << file_content
          t.flush; t.rewind

          OpenMailer.send_ack_file_exception(email_address, messages, t, file_name, sync_code).deliver!
        end
      end
      
      #override this to do custom handling if a product isn't found in the database
      def find_object row, opts
        module_type = opts[:module_type].blank? ? 'Product' : opts[:module_type]
        cm = CoreModule.find_by_class_name(module_type)
        SearchCriterion.new(model_field_uid:cm.unique_id_field.uid,
          operator:'eq',value:row[0]).apply(cm.klass).first
      end

    end
  end
end

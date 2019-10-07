require 'open_chain/integration_client_parser'

module OpenChain
  module CustomHandler
    # Process CSV Acknowledgements
    class AckFileHandler
      include IntegrationClientParser

      def self.parse file_contents, opts = {}
        raise ArgumentError, "Opts must have a :sync_code hash key." unless opts[:sync_code]
        raise ArgumentError, "Opts must have an s3 :key hash key." unless opts[:key]
        
        opts[:email_warnings] = true if opts[:email_warnings].blank?

        self.new.process_ack_file file_contents, opts[:sync_code], opts[:username], opts
      end
      
      def process_ack_file file_content, sync_code, username, opts={}
        file_name = inbound_file.file_name

        errors = get_ack_file_errors file_content, file_name, sync_code, opts
        handle_errors(errors, username, opts[:mailing_list_code], file_name, file_content, sync_code) unless errors.blank?
      end

      def get_ack_file_errors file_content, file_name, sync_code, opts={}
        cm = core_module(opts)
        errors = []
        row_count = 0
        csv_opts = opts[:csv_opts] ? opts[:csv_opts] : {}

        # Trim each line so that there's no trailing spaces on each line
        # and then use CSV.parse so that we're handling quoted newlines correctly
        output = StringIO.new
        StringIO.new(file_content).each do |line|
          output << (line.strip + "\n")
        end
        output.rewind
        CSV.parse(output.read, csv_opts) do |row|
          row_count += 1
          next if row_count == 1
          # Allows for optional 'error description' value in the 4th column.  Older ack files will not contain this.
          if (row.size < 3)
            errors << "Malformed response line: #{row.to_csv.strip}"
            next
          end
          prod = find_object row, opts
          if prod.nil?
            errors << "#{cm.label} #{row[0]} confirmed, but it does not exist."
            next
          end
          sync = prod.sync_records.find_by_trading_partner sync_code 
          if sync.nil?
            errors << "#{cm.label} #{row[0]} confirmed, but it was never sent." if opts[:email_warnings] == true
            next
          end
          error_description = row[3].try(:strip)
          # A column C value of "OK" means no error, and there will therefore be no fail message.  Assuming we
          # get something other than "OK" in C, that becomes our fail message UNLESS we get a value in column D
          # (error description, added spring 2019). D wins out over C in that case.
          fail_message = row[2].to_s.strip.upcase=='OK' ? nil : (error_description.present? ? error_description : row[2])
          sync.update_attributes(:confirmed_at=>Time.zone.now,:confirmation_file_name=>file_name,:failure_message=>fail_message)
          errors << "#{cm.label} #{row[0]} failed: #{fail_message}" unless fail_message.blank?
        end
        errors
      end

      # override this to do custom handling with the given array of error messages
      def handle_errors errors, username, mailing_list_code, file_name, file_content, sync_code
        messages = ["File Name: #{file_name}"]
        messages += errors

        email_addresses = []
        email_addresses = User.where(username: username).pluck(:email) unless username.blank?

        if !mailing_list_code.blank?
          list = MailingList.where(system_code: mailing_list_code).first
          email_addresses << list if list
        end

        email_addresses = ["support@vandegriftinc.com"] if email_addresses.blank?

        Tempfile.open(["temp",".csv"]) do |t|
          t << file_content
          t.flush
          t.rewind

          OpenMailer.send_ack_file_exception(email_addresses, messages, t, file_name, sync_code).deliver_now
        end
      end
      
      #override this to do custom handling if a product isn't found in the database
      def find_object row, opts
        cm = core_module opts
        SearchCriterion.new(model_field_uid:cm.unique_id_field.uid,
          operator:'eq',value:row[0]).apply(cm.klass).first
      end

      def core_module opts
        module_type = opts[:module_type].blank? ? 'Product' : opts[:module_type]
        CoreModule.find_by_class_name(module_type)
      end

    end
  end
end

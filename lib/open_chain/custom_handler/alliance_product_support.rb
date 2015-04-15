module OpenChain
  module CustomHandler
    module AllianceProductSupport
      def ftp_credentials
        {:username=>'VFITRACK',:password=>'RL2VFftp',:server=>'ftp2.vandegriftinc.com',:folder=>'to_ecs/alliance_products',:remote_file_name=>remote_file_name}
      end

      def preprocess_row row, opts = {}
        row.each do |column, val|
          # So, what we're doing here is attempting to transliterate any NON-ASCII data...
          # If that's not possible, we're using an ASCII bell character.

          # If the translated text then returns that we have a bell character (which really should never
          # occurr naturally in data), then we know we have an untranslatable char and we'll hard stop.
          
          if val.is_a? String
            translated = ActiveSupport::Inflector.transliterate(val, "\007")
            if translated =~ /\x07/
              raise "Untranslatable Non-ASCII character for Part Number '#{row[0]}' found at string index #{$~.begin(0)} in product query column #{column}: '#{val}'."
            else
              # Strip newlines from everything, there's no scenario where a newline should be present in the file data
              row[column] = translated.gsub(/\r?\n/, " ")
            end
          end
        end

        super(row)
      rescue => e
        # Don't let a single product stop the rest of them from being sent.
        e.log_me
        nil
      end
    end
  end
end

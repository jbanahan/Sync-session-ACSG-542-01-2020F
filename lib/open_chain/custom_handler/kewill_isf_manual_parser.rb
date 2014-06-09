module OpenChain
  module CustomHandler
    class KewillIsfManualParser

      def initialize custom_file
        @custom_file = custom_file
      end

      def can_view? user
        user.edit_security_filings?
      end

      def self.process_s3 s3_path, bucket = OpenChain::S3.bucket_name
        OpenChain::S3.download_to_tempfile(bucket, s3_path) do |file|
          CSV.parse(file) do |row|
            isf_number = row[8]
            status = row[2]
            SecurityFiling.where(host_system_file_number: isf_number).each do |sf|
              sf.status_code = status
              sf.save!
            end
          end
        end
      end

      def process user
        if @custom_file && @custom_file.attached && @custom_file.attached.path
          KewillIsfManualParser.process_s3 @custom_file.attached.path, OpenChain::S3.bucket_name(:production)

          user.messages.create(subject: "Kewill ISF Manual Parser Complete",
            body: "Parsing of file '#{@custom_file.attached_file_name}' has finished processing.")
        end
      end
    end
  end
end
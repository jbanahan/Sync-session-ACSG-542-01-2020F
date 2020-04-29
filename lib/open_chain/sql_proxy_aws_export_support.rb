require 'open_chain/s3'
require 'open_chain/sqs'
require 'open_chain/integration_client'

module OpenChain; module SqlProxyAwsExportSupport
  extend ActiveSupport::Concern

  module ClassMethods
    def aws_file_export_context_data s3_export_path
      {s3_bucket: OpenChain::S3.integration_bucket_name, s3_path: s3_export_path, sqs_queue: default_sqs_queue_url}
    end

    def s3_export_path_from_parser parser_class, file_extension, path_date: nil, filename_prefix: nil
      integration_folder = Array.wrap(parser_class.integration_folder).first

      s3_export_path(integration_folder, file_extension: file_extension, path_date: path_date, filename_prefix: filename_prefix)
    end

    # This method constructs a return path for anything writing to s3 using the given parser identifier string.  This
    # string should be the SAME value used for the parser in IntegrationClient.
    #
    def s3_export_path_from_parser_identifier parser_identifier, file_extension, system_code: MasterSetup.get.system_code, path_date: nil, filename_prefix: nil
      raise "Unable to construct accurate s3 export path when system code is blank." if system_code.blank?

      s3_path_prefix = "#{system_code}/#{parser_identifier}"

      s3_export_path(s3_path_prefix, file_extension: file_extension, path_date: path_date, filename_prefix: filename_prefix)
    end

    def s3_export_path s3_path_prefix, file_extension: nil, path_date: nil, filename_prefix: nil
      path_date = Time.zone.now if path_date.nil?

      prefix = ""
      if !filename_prefix.blank?
        prefix = "#{filename_prefix}-"
      end

      filename = "#{prefix}#{path_date.strftime("%Y-%m-%d-%H-%M-%S-%L")}"
      filename += ".#{file_extension}" unless file_extension.blank?

      # Just use the date as the non-prefix component of the filename
      Pathname.new(OpenChain::S3.integration_subfolder_path(s3_path_prefix, path_date)).join("#{filename}").to_s
    end

    def default_sqs_queue_url
      @queue_url ||= begin
        default_queue_name = OpenChain::IntegrationClient.default_integration_queue_name
        queue_url = OpenChain::SQS.get_queue_url default_queue_name
        raise "Unable to determine sqs queue url for '#{default_queue_name}'." if queue_url.blank?
        queue_url
      end
    end
  end

end; end

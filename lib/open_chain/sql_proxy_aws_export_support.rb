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

      path_date = Time.zone.now if path_date.nil?

      prefix = ""
      if !filename_prefix.blank?
        prefix = "#{filename_prefix}-"
      end
      # Just use the date as the filename
      Pathname.new(OpenChain::S3.integration_subfolder_path(integration_folder, path_date)).join("#{prefix}#{path_date.strftime("%Y-%m-%d-%H-%M-%S-%L")}.#{file_extension}").to_s
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
  
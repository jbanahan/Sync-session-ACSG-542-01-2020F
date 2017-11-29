require 'open_chain/kewill_sql_proxy_client'
require 'open_chain/polling_job'
require 'open_chain/s3'
require 'open_chain/sqs'

require 'open_chain/custom_handler/vandegrift/kewill_statement_parser'

module OpenChain; module CustomHandler; module Vandegrift; class KewillStatementRequester
  extend OpenChain::PollingJob

  def self.run_schedulable opts = {}
    opts = opts.with_indifferent_access
    poll do |last_run, current_run|
      aws_data = aws_context_data(current_run, opts)
      sql_proxy_client.request_updated_statements last_run, current_run, aws_data[:s3_bucket], aws_data[:s3_path], aws_data[:sqs_queue], customer_numbers: opts[:customer_numbers]
    end
  end

  def self.timezone
    "America/New_York"
  end

  def self.request_daily_statements statement_numbers
    aws_data = aws_context_data(Time.zone.now.in_time_zone(timezone), {})
    sql_proxy_client.request_daily_statements(statement_numbers, aws_data[:s3_bucket], aws_data[:s3_path], aws_data[:sqs_queue])
  end

  def self.request_monthly_statements statement_numbers
    aws_data = aws_context_data(Time.zone.now.in_time_zone(timezone), {})
    sql_proxy_client.request_monthly_statements(statement_numbers, aws_data[:s3_bucket], aws_data[:s3_path], aws_data[:sqs_queue])
  end

  def self.sql_proxy_client
    OpenChain::KewillSqlProxyClient.new
  end
  private_class_method :sql_proxy_client

  def self.aws_context_data date, opts
    default_context = {s3_bucket: opts['s3_bucket'], s3_path: opts['s3_path'], sqs_queue: opts['sqs_queue']}
    if default_context[:s3_bucket].blank?
      default_context[:s3_bucket] = OpenChain::S3.integration_bucket_name
    end

    if default_context[:s3_path].blank?
      integration_folder = Array.wrap(OpenChain::CustomHandler::Vandegrift::KewillStatementParser.integration_folder).first
      # Just use the date as the filename
      default_context[:s3_path] = Pathname.new(OpenChain::S3.integration_subfolder_path(integration_folder, date)).join("#{date.strftime("%Y%m%d%H%M%S%L")}.json").to_s
    end

    if default_context[:sqs_queue].blank?
      default_queue_name = OpenChain::IntegrationClient.default_integration_queue_name
      queue_url = OpenChain::SQS.get_queue_url default_queue_name
      raise "Unable to determine sqs queue url for '#{default_queue_name}'." if queue_url.blank?  
      default_context[:sqs_queue] = queue_url
    end

    default_context
  end
  private_class_method :aws_context_data

end; end; end; end;
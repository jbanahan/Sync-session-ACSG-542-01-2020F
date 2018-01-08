require 'open_chain/polling_job'
require 'open_chain/kewill_sql_proxy_client'
require 'open_chain/custom_handler/vandegrift/kewill_statement_parser'

module OpenChain; module CustomHandler; module Vandegrift; class KewillStatementRequester
  extend OpenChain::PollingJob

  def self.run_schedulable opts = {}
    opts = opts.with_indifferent_access
    poll do |last_run, current_run|
      client = sql_proxy_client
      aws_data = aws_context_data(client, last_run, opts)
      client.request_updated_statements last_run, current_run, aws_data[:s3_bucket], aws_data[:s3_path], aws_data[:sqs_queue], customer_numbers: opts[:customer_numbers]
    end
  end

  def self.timezone
    "America/New_York"
  end

  def self.request_daily_statements statement_numbers
    client = sql_proxy_client
    aws_data = aws_context_data(client, Time.zone.now.in_time_zone(timezone), {})
    client.request_daily_statements(statement_numbers, aws_data[:s3_bucket], aws_data[:s3_path], aws_data[:sqs_queue])
  end

  def self.request_monthly_statements statement_numbers
    client = sql_proxy_client
    aws_data = aws_context_data(client, Time.zone.now.in_time_zone(timezone), {})
    client.request_monthly_statements(statement_numbers, aws_data[:s3_bucket], aws_data[:s3_path], aws_data[:sqs_queue])
  end

  def self.sql_proxy_client
    OpenChain::KewillSqlProxyClient.new
  end

  def self.aws_context_data proxy_client, date, opts
    context = {s3_bucket: opts['s3_bucket'], s3_path: opts['s3_path'], sqs_queue: opts['sqs_queue']}

    default_aws_data = proxy_client.aws_context_hash OpenChain::CustomHandler::Vandegrift::KewillStatementParser, "json", path_date: date
    
    context[:s3_bucket] = default_aws_data[:s3_bucket] if context[:s3_bucket].blank?
    context[:s3_path] = default_aws_data[:s3_path] if context[:s3_path].blank?
    context[:sqs_queue] = default_aws_data[:sqs_queue] if context[:sqs_queue].blank?

    context
  end

end; end; end; end;
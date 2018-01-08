require 'open_chain/custom_handler/vandegrift/kewill_statement_requester'

module OpenChain; module CustomHandler; module Vandegrift; class KewillMonthlyStatementRequester < OpenChain::CustomHandler::Vandegrift::KewillStatementRequester

  def self.run_schedulable opts = {}
    opts = opts.with_indifferent_access
    start_date, end_date = dates(opts)

    client = sql_proxy_client
    aws_data = aws_context_data(client, Time.zone.now, opts)
    client.request_monthly_statements_between(start_date, end_date, aws_data[:s3_bucket], aws_data[:s3_path], aws_data[:sqs_queue], customer_numbers: opts[:customer_numbers])
  end

  def self.dates opts
    tz = ActiveSupport::TimeZone["America/New_York"]
    if opts[:start_date]
      start_date = tz.parse(opts[:start_date]).to_date
    else
      start_date = (tz.now - 1.day).to_date
    end

    if opts[:end_date]
      end_date = (tz.parse opts[:end_date]).to_date
    else
      end_date = tz.now.to_date
    end

    [start_date, end_date]
  end

end; end; end; end
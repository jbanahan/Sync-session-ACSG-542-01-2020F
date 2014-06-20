require 'open_chain/sql_proxy_client'

module OpenChain; module CustomHandler; module Intacct; class IntacctAllianceDataRequester

  def self.run_schedulable opts = {}
    client = self.new
    if opts['checks'].to_s == "true"
      client.request_checks opts
    else
      client.request_invoice_numbers opts
    end
  end

  def initialize client = OpenChain::SqlProxyClient.new
    @client = client
  end

  def request_invoice_numbers opts = {}
    # Translate days ago to an actual date then use the proxy client.
    starting_invoice_date = reference_date opts, 5
    @client.request_alliance_invoice_numbers_since starting_invoice_date
  end

  def request_checks opts = {}
    check_date = reference_date opts, 2
    @client.request_advance_checks check_date
  end

  private
    def reference_date opts, default_ago
      days_ago = opts['days_ago'].nil? ? default_ago : opts['days_ago'].to_i

      (Time.zone.now - days_ago.days).to_date
    end

end; end; end; end;
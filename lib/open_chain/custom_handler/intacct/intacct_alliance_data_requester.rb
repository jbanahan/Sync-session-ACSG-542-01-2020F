require 'open_chain/sql_proxy_client'

module OpenChain; module CustomHandler; module Intacct; class IntacctAllianceDataRequester

  def self.run_schedulable opts = {}
    client = self.new
    if opts['days_ago']
      client.request_invoice_numbers opts['days_ago'].to_i
    else
      client.request_invoice_numbers
    end
  end

  def initialize client = OpenChain::SqlProxyClient.new
    @client = client
  end

  def request_invoice_numbers days_ago = 5
    # Translate days ago to an actual date then use the proxy client.
    starting_invoice_date = (Time.zone.now - days_ago.days).to_date
    @client.request_alliance_invoice_numbers_since starting_invoice_date
  end

end; end; end; end;
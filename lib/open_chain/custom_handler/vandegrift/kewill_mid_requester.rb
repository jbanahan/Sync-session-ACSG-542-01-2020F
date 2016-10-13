require 'open_chain/kewill_sql_proxy_client'
require 'open_chain/polling_job'

module OpenChain; module CustomHandler; module Vandegrift; class KewillMidRequester
  extend OpenChain::PollingJob

  def self.run_schedulable opts = {}
    poll do |last_run, current_run|
      sql_proxy_client.request_mid_updates last_run.to_date
    end
  end

  def self.timezone
    "America/New_York"
  end

  def self.sql_proxy_client
    OpenChain::KewillSqlProxyClient.new
  end
  private_class_method :sql_proxy_client



end; end; end; end;
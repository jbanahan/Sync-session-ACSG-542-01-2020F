require 'open_chain/fenix_sql_proxy_client'
require 'open_chain/polling_job'

module OpenChain; module CustomHandler; class FenixDocumentsRequester
  extend OpenChain::PollingJob

  def self.run_schedulable opts = {}
    offset = opts['polling_offset'].presence || 300
    poll(polling_offset: offset) do |last_run, current_run|
      sql_proxy_client.request_images_added_between last_run, current_run
    end
  end

  def self.sql_proxy_client
    OpenChain::FenixSqlProxyClient.new
  end
  private_class_method :sql_proxy_client

end; end; end;

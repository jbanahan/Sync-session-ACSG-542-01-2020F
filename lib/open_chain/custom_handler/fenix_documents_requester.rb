require 'open_chain/fenix_sql_proxy_client'
require 'open_chain/polling_job'

module OpenChain; module CustomHandler; class FenixDocumentsRequester
  extend OpenChain::PollingJob

  def self.run_schedulable opts = {}
    offset = opts['polling_offset'].presence || 300
    conf = imaging_config
    poll(polling_offset: offset) do |last_run, current_run|
      sql_proxy_client.request_images_added_between last_run, current_run, conf[:s3_bucket], conf[:sqs_receive_queue]
    end
  end

  def self.sql_proxy_client
    OpenChain::FenixSqlProxyClient.new
  end
  private_class_method :sql_proxy_client

  def self.imaging_config 
    # Even though this says "kewill_imaging" this is really just the AWS S3 / SQS data to relay to the service to utilize 
    # when sending the documents back
    MasterSetup.secrets["kewill_imaging"].with_indifferent_access
  end
  private_class_method :imaging_config

end; end; end;

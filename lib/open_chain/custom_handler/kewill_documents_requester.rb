require 'open_chain/kewill_imaging_sql_proxy_client'
require 'open_chain/polling_job'

module OpenChain; module CustomHandler; class KewillDocumentsRequester
  extend OpenChain::PollingJob

  def self.run_schedulable opts = {}
    # We're adding a 5 minute offset here because the Kewill Imaging database
    # doesn't (seemingly) utilize transactional updates when putting documents in, so I don't
    # want to encounter a situation where there's a record of the document in the imaging table
    # but the image itself is still being pushed into the database table that houses the actual imaging bytes.
    # So we offset by 5 minutes to try and mitigate this.

    offset = opts['polling_offset'].presence || 300
    conf = imaging_config
    poll(polling_offset: offset) do |last_run, current_run|
      sql_proxy_client.request_images_added_between last_run, current_run, opts["customer_numbers"], conf[:s3_bucket], conf[:sqs_receive_queue]
    end
  end

  def self.sql_proxy_client
    OpenChain::KewillImagingSqlProxyClient.new
  end
  private_class_method :sql_proxy_client

  def self.imaging_config
    MasterSetup.secrets["kewill_imaging"].with_indifferent_access
  end
  private_class_method :imaging_config

end; end; end;

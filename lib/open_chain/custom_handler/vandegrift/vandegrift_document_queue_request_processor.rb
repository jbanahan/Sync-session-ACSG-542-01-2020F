require 'open_chain/kewill_imaging_sql_proxy_client'
require 'open_chain/fenix_sql_proxy_client'

module OpenChain; module CustomHandler; module Vandegrift; class VandegriftDocumentQueueRequestProcessor

  class InvalidQueueSystemError < StandardError; end;

  def self.run_schedulable opts = {}
    process_document_request_queue(system: opts["system"])
  end

  def self.process_document_request_queue wait_time_minutes: nil, system: nil
    config = imaging_config
    worker_name = "VandegriftDocumentQueueRequestProcessor:#{Process.pid}"
    system = nil if system.blank?

    item_count = 0
    now = Time.zone.now
    loop do
      query = DocumentRequestQueueItem.where("request_at <= ?", now)
      query = query.where(system: system) unless system.blank?

      # This works on MySQL since it supports
      # UPDATE...LIMIT. It uses separate queries to lock and return the job
      # This effectively locks the first job available
      count = query.limit(1).update_all(locked_by: worker_name, locked_at: Time.zone.now)
      break if count == 0

      # Purposefully not including locked_at so that if for some reason all the items aren't processed
      # they'll be reprocesed on the next loop
      queue_items = DocumentRequestQueueItem.where(locked_by: worker_name).all
      queue_items.each do |item|
        begin
          if item.system.to_s.downcase == "kewill"
            request_kewill_images_for_queue_item(item, config)
          elsif item.system.to_s.downcase == "fenix"
            request_fenix_images_for_queue_item(item, config)
          else
            message = "Invalid document request queue item received with system '#{item.system}' with identifier '#{item.identifier}'."
            item.destroy
            raise InvalidQueueSystemError, message
          end
          item.destroy
          item_count += 1
        rescue InvalidQueueSystemError => se
          se.log_me
        rescue => e
          e.log_me "Failed to process document request for system '#{item.system}' with identifier '#{item.identifier}'."
          # Set the request_at time, so that this queue item is not picked up again for another job iteration
          # Essentially, this is just introducing a sleep time into the process so that we don't constantly
          # loop over errored items
          item.update_column(:request_at, (item.locked_at + 1.minute))
        end
      end
    end

    item_count
  end

  def self.request_kewill_images_for_queue_item queue_item, imaging_config
    OpenChain::KewillImagingSqlProxyClient.new.request_images_for_file(queue_item.identifier, imaging_config['s3_bucket'], imaging_config['sqs_receive_queue'])
  end

  def self.request_fenix_images_for_queue_item queue_item, imaging_config
    OpenChain::FenixSqlProxyClient.new.request_images_for_transaction_number(queue_item.identifier, imaging_config['s3_bucket'], imaging_config['sqs_receive_queue'])
  end

  def self.imaging_config
    # The same s3 bucket and sqs queue can be used for both Fenix and Kewill
    config = MasterSetup.secrets["kewill_imaging"]
    raise "No Kewill Imaging config set up.  Make sure a 'kewill_imaging' key is configured in secrets.yml." if config.blank?
    config
  end
  private_class_method :imaging_config

end; end; end; end;
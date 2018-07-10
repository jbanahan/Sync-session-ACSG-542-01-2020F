require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/uncancelled_shipment_comparator'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberBookingRequestShipmentComparator
  extend OpenChain::EntityCompare::UncancelledShipmentComparator
  include OpenChain::FtpFileSupport
  include OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    super(snapshot) && snapshot.recordable.try(:booking_received_date).present? && snapshot.recordable.booking_received_date.to_date >= Date.new(2018, 6, 1)
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    self.new.compare(id)
  end

  def compare id
    # There appears to be some strange issue with booking requests, where we're not hitting the situation
    # where the date changes between the old / new - No idea why this is happening.

    # So what we're going to do is just look for shipment to not have a sync record or one where the booking
    # requested date is > sent at
    shipment = Shipment.where(id: id).first
    if shipment
      Lock.with_lock_retry(shipment) do
        send_booking_request_xml shipment
      end
    end
  end

  private
    def send_booking_request_xml shipment
      return nil if shipment.booking_received_date.nil? || shipment.booking_received_date.to_date < Date.new(2018, 6, 1)
      
      sr = shipment.sync_records.where(trading_partner: 'Booking Request').first_or_initialize
      # No updated booking requests should be sent ever...if the booking was bad, the vendor will either 
      # redo the booking after clearing it, or lumber will adjust it and notify Allport through manual channels
      # with changes / fixes.
      return nil unless sr.sent_at.nil?

      doc = OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestXmlGenerator.generate_xml shipment

      Tempfile.open(["booking_request_#{shipment.reference}_",'.xml']) do |tf|
        doc.write tf
        tf.flush
        # Just use the current time as the as the basis for generating the timestamp and sent_at value
        current_time = Time.zone.now
        Attachment.add_original_filename_method tf, "BR_#{shipment.reference}_#{current_time.strftime('%Y%m%d%H%M%S')}.xml"

        ftp_sync_file tf, sr, connect_vfitrack_net(ftp_directory)

        sr.update_attributes! sent_at: current_time, confirmed_at: (current_time + 1.minute)
      end
    end

    def ftp_directory
      folder = "to_ecs/lumber_booking_request#{MasterSetup.get.production? ? '' : '_test'}"
      folder
    end

end; end; end; end;
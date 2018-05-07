require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/uncancelled_shipment_comparator'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberBookingRequestShipmentComparator
  extend OpenChain::EntityCompare::UncancelledShipmentComparator
  include OpenChain::FtpFileSupport
  include OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    super(snapshot) && snapshot.recordable.try(:booking_received_date).present?
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    self.new.compare(id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
  end

  def compare id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    old_json = get_json_hash(old_bucket, old_path, old_version)
    old_booking_received_date = mf(old_json, 'shp_booking_received_date')

    new_json = get_json_hash(new_bucket, new_path, new_version)
    new_booking_received_date = mf(new_json, 'shp_booking_received_date')

    if (old_booking_received_date != new_booking_received_date)
      shipment = Shipment.where(id: id).first
      if shipment
        Lock.with_lock_retry(shipment) do
          send_booking_request_xml shipment
        end
      end
    end
  end

  private
    def send_booking_request_xml shipment
      doc = OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestXmlGenerator.generate_xml shipment
      sr = shipment.sync_records.where(trading_partner: 'Booking Request').first_or_initialize

      Tempfile.open(["booking_request_#{shipment.reference}_",'.xml']) do |tf|
        doc.write tf
        tf.flush
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
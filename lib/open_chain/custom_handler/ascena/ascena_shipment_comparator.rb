require 'open_chain/entity_compare/shipment_comparator'
require 'open_chain/custom_handler/ascena/ascena_shipment_ci_load_generator'

module OpenChain; module CustomHandler; module Ascena; class AscenaShipmentComparator
  extend OpenChain::EntityCompare::ShipmentComparator

  def self.accept? snapshot
    accept = super

    accept && snapshot.try(:recordable).try(:importer).try(:system_code) == "ASCENA"
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    # Really, all we're doing here is finding the shipment, seeing if it's been synced already.
    # If not, then we're syncing it..doing it this way allows for a very easy screen edits and resend
    # should we move away from the straight CI Load file sends.
    shipment = Shipment.where(id: id).first
    if shipment
      Lock.with_lock_retry(shipment) do
        sr = shipment.sync_records.where(trading_partner: "ASCE").first_or_initialize
        if !sr.persisted?
          ascena_generator.generate_and_send shipment
          sr.sent_at = Time.zone.now
          sr.confirmed_at = (sr.sent_at + 1.minute)
          sr.save!
        end
      end
    end
  end

  def self.ascena_generator
    OpenChain::CustomHandler::Ascena::AscenaShipmentCiLoadGenerator.new
  end

end; end; end; end
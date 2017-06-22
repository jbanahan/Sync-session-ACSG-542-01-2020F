require 'open_chain/entity_compare/shipment_comparator'
require 'open_chain/custom_handler/under_armour/under_armour_fenix_invoice_generator'

module OpenChain; module CustomHandler; module UnderArmour; class UnderArmourShipmentComparator
  extend OpenChain::EntityCompare::ShipmentComparator

  def self.accept? snapshot
    accept = super

    accept && snapshot.try(:recordable).try(:importer).try(:system_code) == "UNDAR"
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    # Really, all we're doing here is finding the shipment, seeing if it's been synced already.
    # If not, then we're syncing it..doing it this way allows for a very easy screen edits and resend
    # should we move away from the straight fenix generator process
    shipment = Shipment.where(id: id).first
    if shipment
      Lock.with_lock_retry(shipment) do
        sr = shipment.sync_records.where(trading_partner: "FENIX-810").first_or_initialize
        # By checking for a sent_at rather than just the existence of a record we can use the screen
        # to resend (since it blanks sent_at)
        if sr.sent_at.nil?
          invoice_generator.generate_and_send_invoice shipment
          sr.sent_at = Time.zone.now
          sr.confirmed_at = (sr.sent_at + 1.minute)
          sr.save!
        end
      end
    end
  end

  def self.invoice_generator
    OpenChain::CustomHandler::UnderArmour::UnderArmourFenixInvoiceGenerator.new
  end

end; end; end; end
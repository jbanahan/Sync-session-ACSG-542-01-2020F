require 'open_chain/entity_compare/invoice_comparator'
require 'open_chain/custom_handler/vandegrift/fenix_nd_invoice_810_generator'

module OpenChain; module CustomHandler; module Pvh; class PvhInvoiceComparator
  extend OpenChain::EntityCompare::InvoiceComparator

  def self.accept? snapshot
    accept = super
    return false unless accept
    snapshot.recordable.try(:importer).try(:system_code) == "PVH" && canadian_invoice?(snapshot.recordable)
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    invoice = Invoice.where(id: id).first
    if invoice
      Lock.db_lock(invoice) do
        self.new.send_invoice invoice
      end
    end

  end

  def send_invoice invoice
    sync_record = invoice.sync_records.find {|sr| sr.trading_partner == "Fenix 810" }
    if sync_record.nil?
      sync_record = invoice.sync_records.build trading_partner: "Fenix 810"
    end

    if sync_record.sent_at.nil?
      generate_and_send_ca_invoice(invoice, sync_record)
      sync_record.sent_at = Time.zone.now
      sync_record.confirmed_at = (Time.zone.now + 1.minute)
      sync_record.save!
    end

    nil
  end

  def self.canadian_invoice? invoice
    # We're going to do this based off the consignee's address being in Canada
    invoice.consignee.try(:addresses).try(:first).try(:country).try(:iso_code) == "CA"
  end

  def generate_and_send_ca_invoice invoice, sync_record
    OpenChain::CustomHandler::Vandegrift::FenixNdInvoice810Generator.new.generate_and_send_810 invoice, sync_record
  end

end; end; end; end
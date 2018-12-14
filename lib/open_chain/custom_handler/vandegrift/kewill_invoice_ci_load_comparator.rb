require 'open_chain/custom_handler/vandegrift/kewill_invoice_generator'
require 'open_chain/entity_compare/invoice_comparator'

module OpenChain; module CustomHandler; module Vandegrift; class KewillInvoiceCiLoadComparator
  extend OpenChain::EntityCompare::InvoiceComparator

  def self.accept? snapshot
    accept = super
    return false unless accept

    alliance_customer_number = snapshot.try(:recordable).try(:importer).try(:alliance_customer_number)
    return false if alliance_customer_number.blank?

    invoice_ci_load_customers = ci_load_data.keys
    invoice_ci_load_customers.include? alliance_customer_number
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
    sync_record = invoice.sync_records.find {|sr| sr.trading_partner == "CI LOAD" }
    if sync_record.nil?
      sync_record = invoice.sync_records.build trading_partner: "CI LOAD"
    end

    if sync_record.sent_at.nil?
      invoice_generator(invoice.importer.alliance_customer_number).generate_and_send_invoice(invoice, sync_record)
      sync_record.sent_at = Time.zone.now
      sync_record.confirmed_at = (Time.zone.now + 1.minute)
      sync_record.save!
    end

    nil
  end

  def invoice_generator alliance_customer_number
    generator_string = self.class.ci_load_data[alliance_customer_number]
    if generator_string.blank?
      return OpenChain::CustomHandler::Vandegrift::KewillInvoiceGenerator.new
    else
      # This assumes the generator class has already been required...it should always be by virtue
      # of the snapshot comparator always running in a delayed job queue (which loads every class/file 
      # in lib)
      return generator_string.constantize.new
    end
  end

  def self.ci_load_data
    DataCrossReference.get_all_pairs(DataCrossReference::INVOICE_CI_LOAD_CUSTOMERS)
  end
end; end; end; end
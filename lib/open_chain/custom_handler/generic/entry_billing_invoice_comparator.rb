require 'open_chain/custom_handler/generic/billing_invoice_generator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/entry_comparator'

module OpenChain; module CustomHandler; module Generic; class EntryBillingInvoiceComparator
  extend OpenChain::EntityCompare::EntryComparator
  include OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    accept = super
    if accept
      entry = snapshot.recordable
      customer_enabled = DataCrossReference.keys(DataCrossReference::BILLING_INVOICE_CUSTOMERS).include?(entry.customer_number)
      accept = customer_enabled && entry.broker_invoices.length > 0
    end
    accept
  end

  def self.compare _type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    entry = Entry.where(id: id).first
    return unless entry

    comp = self.new
    old_snapshot_json = comp.get_json_hash(old_bucket, old_path, old_version)
    new_snapshot_json = comp.get_json_hash(new_bucket, new_path, new_version)
    comp.generate_billing_invoices entry, old_snapshot_json, new_snapshot_json
  end

  # Generates a billing invoice XML for any broker invoice that has been added to the entry.
  def generate_billing_invoices entry, old_snapshot_json, new_snapshot_json
    added_broker_invoices = added_child_entities(old_snapshot_json, new_snapshot_json, "BrokerInvoice")
    Lock.db_lock(entry) do
      added_broker_invoices.each do |bi_snap|
        broker_inv = entry.broker_invoices.find { |bi| bi.id == record_id(bi_snap) }
        if broker_inv
          generator.generate_and_send broker_inv
        end
      end
    end
  end

  def generator
    OpenChain::CustomHandler::Generic::BillingInvoiceGenerator.new
  end

end; end; end; end
require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/ascena/ascena_billing_invoice_file_generator'

module OpenChain; module CustomHandler; module Ascena; class AscenaEntryBillingComparator
  extend OpenChain::EntityCompare::EntryComparator
  extend OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    return false unless super
    ent = snapshot.try(:recordable)
    ent.source_system == Entry::KEWILL_SOURCE_SYSTEM &&
      (ent.customer_number == "ASCE" || (ent.customer_number == "MAUR" && ent.entry_filed_date.try(:>=, "2019-05-07")))
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    snapshot = get_json_hash(new_bucket, new_path, new_version)

    if snapshot
      ascena_generator.generate_and_send(snapshot)
    end
  end

  def self.ascena_generator
    OpenChain::CustomHandler::Ascena::AscenaBillingInvoiceFileGenerator.new
  end

end; end; end; end

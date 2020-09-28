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
      ent.entry_type != "06" && # filter out FTZ
      (ent.entry_filed_date && /ISF/i.match(ent.customer_references).nil?) && # filter out ISF shell records
      (ent.customer_number == "ASCE" || (ent.customer_number == "MAUR" && ent.entry_filed_date >= "2019-05-07"))
  end

  def self.compare _type, _id, _old_bucket, _old_path, _old_version, new_bucket, new_path, new_version
    snapshot = get_json_hash(new_bucket, new_path, new_version)

    if snapshot
      ascena_generator.generate_and_send(snapshot)
    end
  end

  def self.ascena_generator
    OpenChain::CustomHandler::Ascena::AscenaBillingInvoiceFileGenerator.new
  end

end; end; end; end

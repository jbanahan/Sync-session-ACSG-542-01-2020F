require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/ascena/ascena_billing_invoice_file_generator'

module OpenChain; module CustomHandler; module Ascena; class AscenaEntryBillingComparator
  extend OpenChain::EntityCompare::EntryComparator
  extend OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    accept = super
    accept && snapshot.try(:recordable).try(:customer_number) == "ASCE" && snapshot.try(:recordable).try(:source_system) == Entry::KEWILL_SOURCE_SYSTEM
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
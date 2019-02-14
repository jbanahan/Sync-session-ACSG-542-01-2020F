require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/pvh/pvh_us_billing_invoice_file_generator'
require 'open_chain/custom_handler/pvh/pvh_canada_billing_invoice_file_generator'

module OpenChain; module CustomHandler; module Pvh; class PvhEntryBillingComparator
  extend OpenChain::EntityCompare::EntryComparator
  extend OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    accept = super
    return false unless accept

    # This is here SOLELY for the production acceptance testing phase...it can be removed once we go 100% live
    # This provides a way to go live without having to do a code update
    if MasterSetup.get.custom_feature?("PVH Billing Testing")
      return false unless has_test_indicator?(snapshot&.recordable)
    end

    ["PVHCANADA", "PVH", "PVHNE", "PVHCA"].include?(snapshot&.recordable&.customer_number) && 
          # The final file logged date check once we're 100% live can be determined later
          snapshot&.recordable&.file_logged_date && snapshot&.recordable&.file_logged_date > Date.new(2018, 12, 1)
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    snapshot = get_json_hash(new_bucket, new_path, new_version)

    if snapshot
      # Check the import country to determine which generator to use
      country = mf(snapshot, :ent_cntry_iso).to_s.upcase
      if country == "US"
        pvh_us_generator.generate_and_send(snapshot)
      elsif country == "CA"
        pvh_ca_generator.generate_and_send(snapshot)
      end
    end
  end

  def self.has_test_indicator? entry
    # Fenix can't key house bills for non-Air shipments, so let them key BILLINGTEST as a container
    entry.house_bills_of_lading.to_s.upcase.include?("BILLINGTEST") || entry.container_numbers.to_s.upcase.include?("BILLINGTEST")
  end

  def self.pvh_us_generator
    OpenChain::CustomHandler::Pvh::PvhUsBillingInvoiceFileGenerator.new
  end

  def self.pvh_ca_generator
    OpenChain::CustomHandler::Pvh::PvhCanadaBillingInvoiceFileGenerator.new
  end

end; end; end; end
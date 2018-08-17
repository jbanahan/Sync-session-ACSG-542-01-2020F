require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/entity_compare/comparator_helper'

module OpenChain; module CustomHandler; module Vandegrift; class KewillIsfBackfillComparator
  extend OpenChain::EntityCompare::EntryComparator
  extend OpenChain::EntityCompare::ComparatorHelper

  def self.populate_isf_data(entry)
    security_filings = find_security_filings(entry)
    return unless security_filings

    security_filings.each do |sf|
      entry_numbers = sf.entry_numbers ? sf.entry_numbers.split("\n") : []
      entry_reference_numbers = sf.entry_reference_numbers ? sf.entry_reference_numbers.split("\n") : []
      next if entry_numbers.include?(entry.entry_number) && entry_reference_numbers.include?(entry.broker_reference)
      unless entry_numbers.include?(entry.entry_number)
        entry_numbers << entry.entry_number
        sf.entry_numbers = entry_numbers.join("\n")
      end
      unless entry_reference_numbers.include?(entry.broker_reference)
        entry_reference_numbers << entry.broker_reference
        sf.entry_reference_numbers = entry_reference_numbers.join("\n")
      end
      sf.save!
    end
  end

  def self.find_security_filings(entry)
    return unless entry.master_bills_of_lading
    master_bills_of_lading = entry.master_bills_of_lading.split('\n')
    SecurityFiling.
        where("master_bill_of_lading IN (?) AND broker_customer_number IN (?)", master_bills_of_lading, customer_number(entry)).
        where("entry_reference_numbers IS NULL OR entry_reference_numbers NOT LIKE ?", "%#{entry.broker_reference}%")

  end

  def self.accept?(snapshot)
    accept = super
    if accept
      entry = snapshot.recordable
      accept = entry && valid_entry?(entry)
    end

    accept
  end

  def self.compare(type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
    entry = Entry.find(id)
    if valid_entry?(entry)
      populate_isf_data(entry)
    end
  end

  def self.valid_entry? entry
    ocean_transport?(entry) && us_country?(entry) && entry.customer_number.present? && entry.master_bills_of_lading.present?
  end

  def self.ocean_transport?(entry)
    ['10','11'].include?(entry.transport_mode_code)
  end

  def self.us_country?(entry)
    entry.source_system == "Alliance"
  end

  def self.customer_number entry
    cust_no = entry.customer_number
    mapped_account = customer_number_mapping[cust_no]
    Array.wrap(mapped_account.presence || cust_no)
  end

  def self.customer_number_mapping
    {"EDDIEFTZ" => ["EBCC", "EDDIE"]}
  end
end; end; end; end
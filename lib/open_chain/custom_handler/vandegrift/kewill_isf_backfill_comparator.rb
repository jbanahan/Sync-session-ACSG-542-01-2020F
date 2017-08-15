require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/entity_compare/comparator_helper'

module OpenChain; module CustomHandler; module Vandegrift; class KewillIsfBackfillComparator
  extend OpenChain::EntityCompare::EntryComparator
  extend OpenChain::EntityCompare::ComparatorHelper

  def compare(entry)
    security_filings = find_security_filings(entry)
    return unless security_filings

    security_filings.each do |sf|
      entry_numbers = sf.entry_numbers ? sf.entry_numbers.split("\n") : []
      entry_reference_numbers = sf.entry_reference_numbers ? sf.entry_reference_numbers.split("\n") : []
      next if entry_numbers.include?(entry.entry_number) && entry_reference_numbers.include(entry.broker_reference)
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

  def find_security_filings(entry)
    return unless entry.master_bills_of_lading
    master_bills_of_lading = entry.master_bills_of_lading.split('\n')
    SecurityFiling.
        where("master_bill_of_lading IN (?) AND broker_customer_number = ?", master_bills_of_lading, entry.customer_number).
        where("entry_reference_numbers IS NULL OR entry_reference_numbers NOT LIKE ?", "%#{entry.broker_reference}%")

  end

  def self.accept?(snapshot)
    super
  end

  def self.compare(type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
    entry = Entry.find(id)
    if ocean_transport?(entry) && us_country?(entry) && entry.customer_number.present? && entry.master_bills_of_lading.present?
      self.new.compare(entry)
    end
  end

  def self.ocean_transport?(entry)
    ['10','11'].include?(entry.transport_mode_code)
  end

  def self.us_country?(entry)
    entry.source_system == "Alliance"
  end
end; end; end; end
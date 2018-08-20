require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/entity_compare/comparator_helper'

module OpenChain; module CustomHandler; module Vandegrift; class KewillIsfBackfillComparator
  extend OpenChain::EntityCompare::EntryComparator
  extend OpenChain::EntityCompare::ComparatorHelper

  def self.populate_isf_data(entry)
    security_filings = find_security_filings(entry)
    return unless security_filings

    security_filings.each do |sf|
      entry_numbers = split_list(sf.entry_numbers)
      entry_reference_numbers = split_list(sf.entry_reference_numbers)
      next if entry_numbers.include?(entry.entry_number) && entry_reference_numbers.include?(entry.broker_reference)
      unless entry_numbers.include?(entry.entry_number)
        entry_numbers << entry.entry_number
        sf.entry_numbers = entry_numbers.join("\n ")
      end
      unless entry_reference_numbers.include?(entry.broker_reference)
        entry_reference_numbers << entry.broker_reference
        sf.entry_reference_numbers = entry_reference_numbers.join("\n ")
      end
      sf.save!
    end
  end

  def self.find_security_filings(entry)
    filings = SecurityFiling.where("entry_reference_numbers IS NULL OR entry_reference_numbers NOT LIKE ?", "%#{entry.broker_reference}%").
                              where("broker_customer_number IN (?)", customer_number(entry))

    master_bills_of_lading = split_list(entry.master_bills_of_lading)
    house_bills_of_lading = split_list(entry.house_bills_of_lading)
    return [] if master_bills_of_lading.blank? && house_bills_of_lading.blank?

    if master_bills_of_lading.length > 0
      filings = filings.where("master_bill_of_lading IN (?)", master_bills_of_lading)
    else
      filings = filings.where("house_bills_of_lading IN (?)", house_bills_of_lading)
    end
    
    filings
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
    ocean_transport?(entry) && us_country?(entry) && entry.customer_number.present? && (entry.master_bills_of_lading.present? || entry.house_bills_of_lading.present?)
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

  def self.split_list list
    list.to_s.split(/\n */)
  end
end; end; end; end
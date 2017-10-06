require 'open_chain/entity_compare/security_filing_comparator'
require 'open_chain/custom_handler/vandegrift/kewill_generic_shipment_ci_load_generator'

module OpenChain; module CustomHandler; module Vandegrift; class KewillCiLoadIsfComparator
  extend OpenChain::EntityCompare::SecurityFilingComparator

  def self.accept? snapshot
    accept = super
    return false unless accept

    isf = snapshot.try(:recordable)
    # We don't want to attempt to try sending a CI Load for the ISF until the status indicates that the ISF
    # fully matched to the carrier's filing.
    return false unless isf.try(:host_system) == "Kewill" && isf.try(:matched?)

    alliance_customer_number = isf.try(:broker_customer_number)
    return false if alliance_customer_number.blank?

    # Validate there's actually lines on the filing too..
    return false unless isf.security_filing_lines.length > 0

    isf_ci_load_customers = ci_load_data.keys
    isf_ci_load_customers.include? alliance_customer_number
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    # Really, all we're doing here is finding the ISF, seeing if it's been synced already.
    # If not, then we're syncing it..doing it this way allows for a very easy resends
    isf = SecurityFiling.where(id: id).first
    if isf

      Lock.with_lock_retry(isf) do
        sr = isf.sync_records.where(trading_partner: "CI LOAD").first_or_initialize
        # By checking for a sent_at rather than just the existence of a record we can use the screen
        # to resend (since it blanks sent_at)
        if sr.sent_at.nil?
          invoice_generator(isf.broker_customer_number).generate_and_send isf
          sr.sent_at = Time.zone.now
          sr.confirmed_at = (sr.sent_at + 1.minute)
          sr.save!
        end
      end
    end
  end

  def self.invoice_generator alliance_customer_number
    generator_string = ci_load_data[alliance_customer_number]
    if generator_string.blank?
      return OpenChain::CustomHandler::Vandegrift::KewillGenericIsfCiLoadGenerator.new
    else
      # This assumes the generator class has already been required...it should always be by virtue
      # of the snapshot comparator always running in a delayed job queue (which loads every class/file 
      # in lib)
      return generator_string.constantize.new
    end
  end

  def self.ci_load_data
    DataCrossReference.get_all_pairs(DataCrossReference::ISF_CI_LOAD_CUSTOMERS)
  end
 
end; end; end; end;
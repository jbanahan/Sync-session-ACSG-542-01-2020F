require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/vandegrift/kewill_entry_comparator'
require 'open_chain/custom_handler/amazon/amazon_billing_file_generator'

module OpenChain; module CustomHandler; module Amazon; class AmazonEntryBillingComparator
  extend OpenChain::EntityCompare::ComparatorHelper
  extend OpenChain::CustomHandler::Vandegrift::KewillEntryComparator

  def self.accept? snapshot
    accept = super
    if accept
      entry = snapshot.recordable
      accept = entry && entry.customer_number.to_s.starts_with?("AMZN") && entry.broker_invoices.length > 0
    end

    accept
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    generator.generate_and_send(get_json_hash(new_bucket, new_path, new_version))
  end

  def self.generator
    OpenChain::CustomHandler::Amazon::AmazonBillingFileGenerator.new
  end

end; end; end; end;
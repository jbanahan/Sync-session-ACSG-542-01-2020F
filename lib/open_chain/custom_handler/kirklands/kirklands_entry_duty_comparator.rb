require 'open_chain/entity_compare/entry_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/kirklands/kirklands_entry_duty_file_generator'

module OpenChain; module CustomHandler; module Kirklands; class KirklandsEntryDutyComparator
  extend OpenChain::EntityCompare::EntryComparator
  extend OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    return false unless super(snapshot)

    return snapshot.recordable&.customer_number == "KLANDS" && (snapshot.recordable&.last_7501_print.present? && snapshot.recordable.last_7501_print.in_time_zone("America/New_York").to_date >= Date.new(2020, 3, 2))
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    new_snapshot = get_json_hash(new_bucket, new_path, new_version)
    entry = find_entity_object(new_snapshot)
    return unless entry

    old_snapshot = get_json_hash(old_bucket, old_path, old_version)
    generate_and_send(entry, old_snapshot, new_snapshot)
  end

  def self.generate_and_send entry, old_snapshot, new_snapshot
    # The trigger for sending a duty file is the Last 7501 Print Date (if it's added or changed we'll generate a file)
    new_print_date = mf(new_snapshot, :ent_last_7501_print)
    return if new_print_date.nil?

    sr = entry.find_or_initialize_sync_record(OpenChain::CustomHandler::Kirklands::KirklandsEntryDutyFileGenerator::SYNC_CODE)
    generate_file = sr.sent_at.nil?

    # If this isn't the first time we've sent the file (or if resend hasn't been enabled), then 
    # check if the last print date was updated.
    if !generate_file
      generate_file = any_value_changed?(old_snapshot, new_snapshot, :ent_last_7501_print)
    end

    if generate_file
      OpenChain::CustomHandler::Kirklands::KirklandsEntryDutyFileGenerator.new.generate_and_send new_snapshot
    end
  end

end; end; end; end;
require 'open_chain/s3'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/entry_comparator'

module OpenChain; module BillingComparators; class EntryComparator
  extend OpenChain::EntityCompare::EntryComparator

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    return unless type == 'Entry'
    new_snapshot_id = EntitySnapshot.where(bucket: new_bucket, doc_path: new_path, version: new_version).first.id
    args = {id: id, old_bucket: old_bucket, old_path: old_path, old_version: old_version, new_bucket: new_bucket, 
            new_path: new_path, new_version: new_version}.merge(new_snapshot_id: new_snapshot_id)
    check_new_entry args
  end

  def self.check_new_entry args
    unless args[:old_bucket]
      BillableEvent.create!(billable_eventable_id: args[:id], billable_eventable_type: "Entry", entity_snapshot_id: args[:new_snapshot_id], 
                            event_type: "entry_new")
    end
  end

end; end; end
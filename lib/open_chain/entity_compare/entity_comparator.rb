require 'open_chain/entity_compare/comparator_registry'

module OpenChain; module EntityCompare; class EntityComparator

  REGISTRIES = [OpenChain::EntityCompare::ComparatorRegistry, OpenChain::EntityCompare::BusinessRuleComparatorRegistry]

  def self.process_by_id snapshot_class_name, snapshot_id
    process snapshot_class_name.constantize.find(snapshot_id)
  end

  def self.handle_snapshot snapshot
    # Only pass off to backend if there's actually a comparator to process this type

    # Make these a lower queue priority..when uploading large numbers of orders/products these can choke out
    # reports and such if they're running at a lower priority
    return unless process_snapshot?(snapshot)

    self.delay(priority: 10).process_by_id(snapshot.class.to_s, snapshot.id) if registry(snapshot)
    
    nil
  end

  def self.registry snapshot
    REGISTRIES.find{ |r| r.registered_for(snapshot).length > 0 }
  end

  def self.process_snapshot? snapshot
    # This method is a simple way to disable all snapshot processing for a distinct snapshot class / type
    return test? || !MasterSetup.get.custom_feature?("Disable #{snapshot.recordable_type} Snapshot Comparators")
  end

  def self.test?
    # PURELY for test casing - it also allows us to not have to have every single test case set up an expectation on Mastersetup if they
    # end up generating a snapshot
    return Rails.env.test?
  end

  def self.snapshot_relation rec, snapshot
    case snapshot.class.to_s
    when "BusinessRuleSnapshot"
      rec.business_rule_snapshots
    when "EntitySnapshot"
      rec.entity_snapshots
    else
      raise "Unexpected Snapshot class '#{snapshot.class}' received."
    end
  end

  def self.process snapshot
    rec = snapshot.recordable
    # It's possible that the recordable is nil at this point if the entity has been deleted and the snapshot has taken a bit of time
    # to process.  For instance, entries can be purged / cancelled.
    return if rec.nil?

    rec_id = snapshot.recordable_id
    rec_type = snapshot.recordable_type
    relation = snapshot_relation(rec, snapshot)
    Lock.acquire("EntityComparator-#{rec_type}-#{rec_id}") do
      #get all unprocessed items, oldest to newest
      all_unprocessed = relation.where(compared_at:nil).where("bucket IS NOT NULL AND doc_path IS NOT NULL").order(:created_at,:id)

      newest_unprocessed = all_unprocessed.last

      # do nothing if everything is processed
      return unless newest_unprocessed


      old_bucket = old_path = old_version = nil

      last_processed = relation.where('compared_at IS NOT NULL').where("bucket IS NOT NULL AND doc_path IS NOT NULL").order('compared_at desc, id desc').limit(1).first

      if last_processed
        # do nothing if newest unprocessed is older than last processed
        return if newest_unprocessed.created_at < last_processed.created_at

        return if newest_unprocessed.created_at == last_processed.created_at && newest_unprocessed.id < last_processed.id

        old_bucket = last_processed.bucket
        old_path = last_processed.doc_path
        old_version = last_processed.version
      end

      
      registry(snapshot).registered_for(snapshot).each do |comp|
        comp.delay(priority: 10).compare(rec_type, rec_id,
          old_bucket, old_path, old_version,
          newest_unprocessed.bucket, newest_unprocessed.doc_path, newest_unprocessed.version
        )
      end

      all_unprocessed.update_all(compared_at:0.seconds.ago)
    end
  end
end; end; end

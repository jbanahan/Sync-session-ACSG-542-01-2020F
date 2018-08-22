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

    self.delay(delay_options).process_by_id(snapshot.class.to_s, snapshot.id) if registry(snapshot)
    
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

    # By applying a database lock on the recordable, we ensure that no other comparators for this recordable are being run for the 
    # same object while this one is (in fact, nothing else should be able to be updating the record across the system either)
    # The db lock also opens a transaction, so we're safe from that vantage point too.
    Lock.db_lock(rec) do
      relation = snapshot_relation(rec, snapshot)

      #get all unprocessed items, oldest to newest
      all_unprocessed = relation.where(compared_at:nil).where("bucket IS NOT NULL AND doc_path IS NOT NULL").order(:created_at,:id)

      newest_unprocessed = all_unprocessed.last

      # do nothing if everything is processed
      return unless newest_unprocessed

      last_processed = relation.where('compared_at IS NOT NULL').where("bucket IS NOT NULL AND doc_path IS NOT NULL").order('compared_at desc, id desc').limit(1).first

      if last_processed
        # do nothing if newest unprocessed is older than last processed
        return if newest_unprocessed.created_at < last_processed.created_at

        return if newest_unprocessed.created_at == last_processed.created_at && newest_unprocessed.id < last_processed.id
      end

      r = registry(snapshot)

      # There's the potential for there not to be anything registered between the time when the snapshot was queued and when it was picked up here.
      if r
        log = nil
        r.registered_for(snapshot).each do |comp|
          # Log all the parameters being passed to the comparators so we can help debug any issues with them 
          # potentially not firing correctly.
          log = create_log(snapshot, last_processed, newest_unprocessed) unless log

          # Last processed could be nil (like for a new record), that's why the try is here
          comp.delay(delay_options).compare(snapshot.recordable_type, snapshot.recordable_id,
            last_processed.try(:bucket), last_processed.try(:doc_path), last_processed.try(:version),
            newest_unprocessed.bucket, newest_unprocessed.doc_path, newest_unprocessed.version
          )
        end
      end

      all_unprocessed.update_all(compared_at:0.seconds.ago)
    end
  end

  def self.create_log snapshot, last_processed, newest_unprocessed
    l = EntityComparatorLog.new
    l.recordable_id = snapshot.recordable_id
    l.recordable_type = snapshot.recordable_type
    # Last processed could be nil, that's why the try is here
    l.old_bucket = last_processed.try(:bucket)
    l.old_path = last_processed.try(:doc_path)
    l.old_version = last_processed.try(:version)
    l.new_bucket = newest_unprocessed.bucket
    l.new_path = newest_unprocessed.doc_path
    l.new_version = newest_unprocessed.version

    l.save!
    l
  end

  def self.delay_options priority: 10
    opts = {priority: priority}
    MasterSetup.config_value(:snapshot_processing_queue) do |queue|
      opts[:queue] = queue
    end

    opts
  end
end; end; end

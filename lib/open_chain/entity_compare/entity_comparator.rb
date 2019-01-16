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
    return true if test?

    # Check to see if we're disabling all comparators for a particular module - which is true in the case of some systems where 
    # we know we have no comparators set up for say a Product or something like that and the customer loads a lot of Products
    return false if MasterSetup.get.custom_feature?("Disable #{snapshot.recordable_type} Snapshot Comparators")

    # Now check to see if snapshots are totally disabled for closed core modules and then check if it's closed
    if MasterSetup.get.custom_feature?("Disable Comparators For Closed Objects")
      return false if snapshot.recordable.respond_to?(:closed?) && snapshot.recordable.closed?
    end

    return true
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
      snapshots = retrieve_snapshots(snapshot, rec) 
      #get all unprocessed items, newest to oldest
      all_unprocessed = snapshots[:unprocessed]
      newest_unprocessed = all_unprocessed.first

      # do nothing if everything is processed
      return unless newest_unprocessed

      last_processed = snapshots[:last_processed]

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
      snapshot.class.where(id: all_unprocessed.map {|s| s.id}, compared_at: nil).update_all(compared_at: Time.zone.now)
    end
  end

  def self.retrieve_snapshots snapshot, parent_object
    # What we're trying to do here is use as few database operations as possible here.  To do that, we're sacrificing memory by loading
    # all the snapshots for an object.
    # This is also an attempt to work around phantom reads by isolating the reads to a single SQL query
    # Phantom reads could and did occur when querying for the unprocessed snapshots and last processed snapshot in multiple queries
    all_snapshots = snapshot_relation(parent_object, snapshot).order(:created_at, :id).to_a

    all_unprocessed = []
    last_processed = nil
    # Iterate over the snapshots in reverse order, once we hit one that has been processed with can quit the loop
    all_snapshots.reverse_each do |snap|
      # Ignore anything where the bucket or path is blank...this can occur if a snapshot could not be written to the bucket
      # Eventually, the snapshot will get written.
      next if snap.bucket.blank? || snap.doc_path.blank?

      if snap.compared_at.nil?
        all_unprocessed << snap
      else
        last_processed = snap
        break
      end
    end

    {unprocessed: all_unprocessed, last_processed: last_processed}
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

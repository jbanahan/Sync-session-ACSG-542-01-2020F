require 'open_chain/entity_compare/comparator_registry'

module OpenChain; module EntityCompare; class EntityComparator

  def self.process_by_id entity_snapshot_id
    process EntitySnapshot.find entity_snapshot_id
  end

  def self.handle_snapshot entity_snapshot
    # Only pass off to backend if there's actually a comparator to process this type

    # Make these a lower queue priority..when uploading large numbers of orders/products these can choke out
    # reports and such if they're running at a lower priority
    return unless process_snapshot?(entity_snapshot)
    self.delay(priority: 10).process_by_id(entity_snapshot.id) if OpenChain::EntityCompare::ComparatorRegistry.registered_for(entity_snapshot).length > 0

    nil
  end

  def self.process_snapshot? entity_snapshot
    # This method is a simple way to disable all snapshot processing for a distinct snapshot class / type
    return test? || !MasterSetup.get.custom_feature?("Disable #{entity_snapshot.recordable_type} Snapshot Comparators")
  end

  def self.test?
    # PURELY for test casing - it also allows us to not have to have every single test case set up an expectation on Mastersetup if they
    # end up generating a snapshot
    return Rails.env.test?
  end

  def self.process entity_snapshot
    rec = entity_snapshot.recordable
    rec_id = entity_snapshot.recordable_id
    rec_type = entity_snapshot.recordable_type
    Lock.acquire("EntityComparator-#{rec_type}-#{rec_id}") do
      #get all unprocessed items, oldest to newest
      all_unprocessed = rec.entity_snapshots.where(compared_at:nil).where("bucket IS NOT NULL AND doc_path IS NOT NULL").order(:created_at,:id)

      newest_unprocessed = all_unprocessed.last

      # do nothing if everything is processed
      return unless newest_unprocessed


      old_bucket = old_path = old_version = nil

      last_processed = rec.entity_snapshots.where('compared_at IS NOT NULL').where("bucket IS NOT NULL AND doc_path IS NOT NULL").order('compared_at desc, id desc').limit(1).first

      if last_processed
        # do nothing if newest unprocessed is older than last processed
        return if newest_unprocessed.created_at < last_processed.created_at

        return if newest_unprocessed.created_at == last_processed.created_at && newest_unprocessed.id < last_processed.id

        old_bucket = last_processed.bucket
        old_path = last_processed.doc_path
        old_version = last_processed.version
      end


      OpenChain::EntityCompare::ComparatorRegistry.registered_for(entity_snapshot).each do |comp|
        comp.delay(priority: 10).compare(rec_type, rec_id,
          old_bucket, old_path, old_version,
          newest_unprocessed.bucket, newest_unprocessed.doc_path, newest_unprocessed.version
        )
      end

      all_unprocessed.update_all(compared_at:0.seconds.ago)
    end
  end
end; end; end

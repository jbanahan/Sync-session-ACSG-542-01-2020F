require 'open_chain/entity_compare/comparator_registry'
module OpenChain; module EntityCompare; class EntityComparator
  def self.process entity_snapshot
    rec = entity_snapshot.recordable
    rec_id = entity_snapshot.recordable_id
    rec_type = entity_snapshot.recordable_type
    Lock.acquire("EntityComparator-#{rec_type}-#{rec_id}") do
      #get all unprocessed items, oldest to newest
      all_unprocessed = rec.entity_snapshots.where(compared_at:nil).order(:created_at)

      newest_unprocessed = all_unprocessed.last

      # do nothing if everything is processed
      return unless newest_unprocessed


      old_bucket = old_path = old_version = nil

      last_processed = rec.entity_snapshots.where('not compared_at is null').order('compared_at desc').limit(1).first
      

      if last_processed
        # do nothing if newest unprocessed is newer than last processed
        return unless newest_unprocessed.created_at > last_processed.created_at
        
        old_bucket = last_processed.bucket
        old_path = last_processed.doc_path
        old_version = last_processed.version
      end


      OpenChain::EntityCompare::ComparatorRegistry.registered.each do |comp|
        comp.delay.compare(rec_type, rec_id, 
          old_bucket, old_path, old_version, 
          newest_unprocessed.bucket, newest_unprocessed.doc_path, newest_unprocessed.version
        )
      end

      all_unprocessed.update_all(compared_at:0.seconds.ago)
    end
  end
end; end; end
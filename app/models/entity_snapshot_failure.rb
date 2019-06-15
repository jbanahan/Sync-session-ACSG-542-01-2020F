# == Schema Information
#
# Table name: entity_snapshot_failures
#
#  created_at    :datetime         not null
#  id            :integer          not null, primary key
#  snapshot_id   :integer
#  snapshot_json :text(2147483647)
#  snapshot_type :string(255)
#  updated_at    :datetime         not null
#

class EntitySnapshotFailure < ActiveRecord::Base
  attr_accessible :snapshot_id, :snapshot, :snapshot_json, :snapshot_type
  
  belongs_to :snapshot, polymorphic: true

  # This method simply looks for any entity snapshot failures in the failure table,
  # stores the buffered json data into s3 and restores the path to the original snapshot.
  def self.run_schedulable
    failures = EntitySnapshotFailure.find_each do |failure|
      begin
        fix_snapshot_data failure
      rescue => e
        e.log_me
      end
    end
  end

  def self.fix_snapshot_data failure
    snapshot = failure.snapshot

    # We don't want to actually record failures here again, since we already have a failure record
    if EntitySnapshot.store_snapshot_json(snapshot, failure.snapshot_json, record_failure: false)

      # We should process the snapshot once we restore it...the comparator is smart enough to know if
      # the data is out of date or if it's still current, so we can always call it here
      OpenChain::EntityCompare::EntityComparator.handle_snapshot snapshot

      failure.destroy
      return true
    else
      return false
    end
  end
end

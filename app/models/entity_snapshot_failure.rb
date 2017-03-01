class EntitySnapshotFailure < ActiveRecord::Base
  belongs_to :snapshot, polymorphic: true
end
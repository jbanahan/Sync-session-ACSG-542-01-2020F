module EntitySnapshotSupport
  def self.included(base)
    base.instance_eval("has_many :entity_snapshots, :as => :recordable") #not doing dependent => destroy so we'll still have snapshots for deleted items
  end

  def last_snapshot
    self.entity_snapshots.order("entity_snapshots.id DESC").first
  end

  def create_snapshot user=User.current
    self.update_attributes(:last_updated_by_id=>user.id) if self.respond_to?(:last_updated_by_id)
    EntitySnapshot.create_from_entity self, user
  end
end

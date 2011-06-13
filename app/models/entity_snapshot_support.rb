module EntitySnapshotSupport
  def self.include(base)
    base.instance_eval("has_many :entity_snapshots, :as => :recordable") #not doing dependent => destroy so we'll still have snapshots for deleted items
  end

  def last_snapshot
    self.entity_snapshots.order("entity_snapshots.id DESC").first
  end

  def create_snapshot user=User.current
    EntitySnapshot.create_from_entity self, user
  end
end

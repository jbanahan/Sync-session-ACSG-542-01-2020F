module EntitySnapshotSupport
  extend ActiveSupport::Concern

  included do
    #not doing dependent => destroy so we'll still have snapshots for deleted items
    has_many :entity_snapshots, :as => :recordable, inverse_of: :recordable
  end

  def last_snapshot
    self.entity_snapshots.order("entity_snapshots.id DESC").first
  end

  def create_snapshot_with_async_option async, user=User.current, imported_file=nil, context=nil
    if async
      self.create_async_snapshot user, imported_file, context
    else
      self.create_snapshot user, imported_file, context
    end
  end

  def create_snapshot user=User.current, imported_file=nil, context=nil
    EntitySnapshot.create_from_entity self, user, imported_file, context
  end

  def create_async_snapshot user=User.current, imported_file=nil, context=nil
    # As of March 27, 2017 disabling async functionality because it was creating bad snapshots
    # due to the snapshot running in a separate DB transaction (.ie thread aquires new connection, thus 
    # causing data contexts to be different and potentially skipping changes a user made)
    # Rails has no way to do distributed transactions (from what I can tell), so this functionality
    # is a total no-go.
    create_snapshot user, imported_file, context
  end

end

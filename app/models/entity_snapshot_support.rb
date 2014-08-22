module EntitySnapshotSupport
  def self.included(base)
    base.instance_eval("has_many :entity_snapshots, :as => :recordable") #not doing dependent => destroy so we'll still have snapshots for deleted items
  end

  def last_snapshot
    self.entity_snapshots.order("entity_snapshots.id DESC").first
  end

  def create_snapshot user=User.current, imported_file=nil
    self.update_attributes(:last_updated_by_id=>user.id) if self.respond_to?(:last_updated_by_id)
    EntitySnapshot.create_from_entity self, user, imported_file
  end

  def create_async_snapshot user=User.current, imported_file=nil
    AsyncSnapshotJob.new.async.perform(self,user,imported_file)
  end

  class AsyncSnapshotJob
    include SuckerPunch::Job

    def perform core_object, user, imported_file
      ActiveRecord::Base.connection_pool.with_connection do
        core_object.create_snapshot user, imported_file
      end
    end
  end
end

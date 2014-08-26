module EntitySnapshotSupport

  mattr_accessor :disable_async

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
    if self.disable_async
      # If we've turned off async, don't run via the standard suckerpunch .async call, even if
      # we use the inline testing functionality, we still seem to get the code run outside of
      # an rspec transaction (leaving garbage testing snapshots around).  At this point, this
      # is the only reason the disable_async is in use
      AsyncSnapshotJob.perform_job self, user, imported_file
    else
      AsyncSnapshotJob.new.async.perform(self,user,imported_file)
    end
    
  end

  class AsyncSnapshotJob
    include SuckerPunch::Job

    def perform core_object, user, imported_file
      # The connection pool stuff is needed since SuckerPunch / Celluloid ends up runnign the following
      # code in a seperate thread which will not have a sql connection established yet, so we get a new one
      # and run in that.
      ActiveRecord::Base.connection_pool.with_connection do
        self.class.perform_job core_object, user, imported_file
      end
    end

    def self.perform_job core_object, user, imported_file
      core_object.create_snapshot user, imported_file
    end
  end
end

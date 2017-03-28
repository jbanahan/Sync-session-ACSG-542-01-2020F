module EntitySnapshotSupport

  mattr_accessor :disable_async

  def self.included(base)
    base.instance_eval("has_many :entity_snapshots, :as => :recordable") #not doing dependent => destroy so we'll still have snapshots for deleted items
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
    # 
    # When a user saved a snapshot in an transaction, the async job would run on a different
    # connection before the transaction was committed, so the snapshot would not include the data
    # that reflected the user's changes when submitted through a controller
    AsyncSnapshotJob.perform_job self, user, imported_file, context
    
    # if self.disable_async
    #   # If we've turned off async, don't run via the standard suckerpunch .async call, even if
    #   # we use the inline testing functionality, we still seem to get the code run outside of
    #   # an rspec transaction (leaving garbage testing snapshots around).  At this point, this
    #   # is the only reason the disable_async is in use
    #   AsyncSnapshotJob.perform_job self, user, imported_file, context
    # else
    #   AsyncSnapshotJob.new.async.perform(self,user,imported_file, context)
    # end
    
  end

  class AsyncSnapshotJob
    include SuckerPunch::Job

    def perform core_object, user, imported_file, context
      # The connection pool stuff is needed since SuckerPunch / Celluloid ends up runnign the following
      # code in a seperate thread which will not have a sql connection established yet, so we get a new one
      # and run in that.
      ActiveRecord::Base.connection_pool.with_connection do
        self.class.perform_job core_object, user, imported_file, context
      end
    end

    def self.perform_job core_object, user, imported_file, context
      core_object.create_snapshot user, imported_file, context
    end
  end
end

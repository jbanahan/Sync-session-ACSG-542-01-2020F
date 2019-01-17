module EntitySnapshotSupport
  extend ActiveSupport::Concern

  included do
    #not doing dependent => destroy so we'll still have snapshots for deleted items until the destroy_snapshots callback completes
    has_many :entity_snapshots, :as => :recordable, inverse_of: :recordable
    has_many :business_rule_snapshots, as: :recordable, inverse_of: :recordable

    # If the owning object is destroyed, we want to initiate the destroy sequence for removing / copying snapshots
    # to a deleted bucket
    after_destroy :async_destroy_snapshots
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

  def async_destroy_snapshots
    return unless destroys_snapshots?

    # We're going to actually copy the snapshots from their current location to a bucket that expires anything over XX days old
    # This allows us some level of grace period to retain snapshots of objects that might have been erroneously purged, but also
    # allows for actually getting rid of snapshots after a time that aren't actually needed and thus not having to continuously pay for them.

    # We're doing this asynchronously so that it's possible to rollback the snapshot deletes if the object's destroy call rolls back.
    # In dev/test..etc, we're going to do this synchronously...otherwise it's likely the snapshots won't actually get deleted
    # since we don't run delayed jobs there.
    klass = self.class
    if MasterSetup.production_env?
      # Make this really low priority
      klass = klass.delay(priority: 100)
    end
    klass.destroy_snapshots(self.id, self.class.name)
    true
  end

  def destroys_snapshots?
    cm = CoreModule.find_by_object(self)
    cm.destroy_snapshots
  end

  module ClassMethods

    def destroy_snapshots recordable_id, recordable_type
      entity_snapshots = EntitySnapshot.where(recordable_id: recordable_id, recordable_type: recordable_type).order(:id).to_a
      rule_snapshots = BusinessRuleSnapshot.where(recordable_id: recordable_id, recordable_type: recordable_type).order(:id).to_a

      all_snapshots = (entity_snapshots + rule_snapshots)
      return unless all_snapshots.length > 0

      # Snapshots we've already deleted will have blank doc paths (also really old snapshot where json was stored directly in the db).
      # We don't need to copy any of these to the deleted bucket.
      snapshots_to_copy = all_snapshots.select { |s| !s.doc_path.blank? }

      snapshots_to_copy.each do |snapshot|
        copied = snapshot.copy_to_deleted_bucket

        if copied
          # This might look weird but we're relying on the delayed jobs retry to make sure all snapshots are copied across.
          # So, if anything in here raises (like if s3 has an issue), the job will try again, and if we mark this particular 
          # snapshot as being copied (by blanking all the paths), then it won't get copied again on the retry.
          # This is a good spot for update_columns when we go to Rails 4 to avoid updating the timestamps for no reason
          snapshot.doc_path = nil
          snapshot.bucket = nil
          snapshot.version = nil
          # have to save without validation otherwise this blows up due to the recordable being nil'ed out by its having
          # been deleted (which is what triggers this code to run)
          snapshot.save(validate: false)
        else
          raise "Failed to copy #{snapshot.class} #{snapshot.id} to deleted bucket." unless copied
        end
      end

      # Now that we know each snapshot was actually copied to the delete bucket we can destroy them all
      all_snapshots.each(&:destroy)

      true
    end
  end

end

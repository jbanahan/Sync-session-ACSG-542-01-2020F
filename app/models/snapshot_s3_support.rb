require 'open_chain/s3'

module SnapshotS3Support
  extend ActiveSupport::Concern

  def copy_to_deleted_bucket
    path = self.class.deleted_path(self)
    return false if path.blank?

    OpenChain::S3.copy_object self.bucket, self.doc_path, path[:bucket], path[:key], from_version: self.version
    return true
  end

  def delete_from_s3
    return if self.bucket.blank? || self.doc_path.blank?

    # We don't want to actually delete from s3 if the bucket isn't the same as this system's bucket.
    # The only time this should really occur is if we generate a test system from a production system's database snapshot
    # When that happens though, we absolutely DO NOT want to delete the actual snapshot from the production source location.
    # (It's fine to delete the database record though from the test system)
    if self.bucket == self.class.bucket_name
      # the s3 delete call will raise an error if it failed to do so
      OpenChain::S3.delete self.bucket, self.doc_path, self.version
    end
    nil
  end

  module ClassMethods
    #bucket name for storing entity snapshots
    def bucket_name env = MasterSetup.rails_env
      # NOTE: DO NOT CHANGE the bucket naming style for live systems without making sure the delete_from_s3 
      # accounts for the potential for multiple bucket naming styles.
      r = "#{env}.#{MasterSetup.get.system_code}.snapshots.vfitrack.net"
      raise "Bucket name too long: #{r}" if r.length > 63
      return r
    end

    def deleted_bucket_name env = MasterSetup.rails_env
      r = "#{env}.deleted-snapshots.vfitrack.net"
    end

    def deleted_path snapshot
      return nil if snapshot.doc_path.blank?

      {bucket: deleted_bucket_name, key: "#{MasterSetup.get.system_code}/#{snapshot.doc_path}"}
    end

    def deleted_snapshot_exists? snapshot
      path = deleted_path(snapshot)
      OpenChain::S3.exist? path[:bucket], path[:key]
    end

    #find or create the bucket for this system's EntitySnapshots
    def create_bucket_if_needed!
      bucket = bucket_name
      return if OpenChain::S3.bucket_exists?(bucket)
      OpenChain::S3.create_bucket!(bucket, versioning: true)
    end

    # write_to_s3 and s3_path is sort of a public API for snapshot-like objects to use so they're stored in the correct snaphsot layout.
    def write_to_s3 snapshot_json, recordable, path_prefix: nil
      zipped_json = ActiveSupport::Gzip.compress snapshot_json

      upload_response = OpenChain::S3.upload_data(bucket_name, s3_path(recordable, path_prefix: path_prefix), zipped_json, content_encoding: "gzip", content_type: "application/json")

      # Technically, version can be nil if uploading to an unversioned bucket..
      # If that happens though, then the bucket we're trying to use is set up wrong.
      # Therefore, we want this to bomb hard with a nil reference error if ver is nil
      raise "Cannot upload snapshots to unversioned bucket.  You must enable versioning on bucket '#{upload_response.bucket}'." if upload_response.version.blank?
      
      {bucket: upload_response.bucket, key: upload_response.key, version: upload_response.version}
    end

    def s3_path recordable, path_prefix: nil
      raise "A snapshot path cannot be created for objects that do not have an id value. Entity Data = #{recordable.inspect}" if recordable.id.blank?

      mod = CoreModule.find_by_object(recordable)
      if mod
        class_name = mod.class_name.underscore
      else
        class_name = recordable.class.to_s.underscore
      end

      # Not entirely sure why this gsub is here since an id is never going to not have a numeric value, but 
      # I'm leaving it in for potential legacy reasons, as it's not hurting anything
      # (I suspect the keybase used to be a more complex value in the original pass at the code.)
      path = "#{class_name}/#{recordable.id.to_s.strip.gsub(/\W/,'_').downcase}.json"
      path_prefix.nil? ? path : "#{path_prefix}/#{path}"
    end

    def retrieve_snapshot_data_from_s3 snapshot
      OpenChain::S3.get_versioned_data snapshot.bucket, snapshot.doc_path, snapshot.version
    end
  end
end
require 'open_chain/s3'

module SnapshotS3Support
  extend ActiveSupport::Concern

  module ClassMethods
    #bucket name for storing entity snapshots
    def bucket_name env=Rails.env
      r = "#{env}.#{MasterSetup.get.system_code}.snapshots.vfitrack.net"
      raise "Bucket name too long: #{r}" if r.length > 63
      return r
    end

    #find or create the bucket for this system's EntitySnapshots
    def create_bucket_if_needed!
      bucket = bucket_name
      return if OpenChain::S3.bucket_exists?(bucket)
      OpenChain::S3.create_bucket!(bucket, versioning: true)
    end

    # write_to_s3 and s3_path is sort of a public API for snapshot-like objects to use so they're stored in the same bucke and manner as "real"
    # snapshots.
    def write_to_s3 snapshot_json, recordable
      upload_response = OpenChain::S3.upload_data(bucket_name, s3_path(recordable), snapshot_json)

      # Technically, version can be nil if uploading to an unversioned bucket..
      # If that happens though, then the bucket we're trying to use is set up wrong.
      # Therefore, we want this to bomb hard with a nil reference error if ver is nil
      raise "Cannot upload snapshots to unversioned bucket.  You must enable versioning on bucket '#{upload_response.bucket}'." if upload_response.version.blank?
      
      {bucket: upload_response.bucket, key: upload_response.key, version: upload_response.version}
    end

    def s3_path recordable
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
      "#{class_name}/#{recordable.id.to_s.strip.gsub(/\W/,'_').downcase}.json"
    end

    def retrieve_snapshot_data_from_s3 snapshot
      data = StringIO.new
      OpenChain::S3.get_versioned_data snapshot.bucket, snapshot.doc_path, snapshot.version, data
      data.rewind
      data.read
    end
  end
end
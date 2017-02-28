if Rails.env.production? && ActiveRecord::Base.connection.table_exists?('entity_snapshots')
  # TODO Make some sort of attribute somewhere that notes the bucket is already created
  # so we don't have to rely on s3 on startup.
  #EntitySnapshot.create_bucket_if_needed!
end

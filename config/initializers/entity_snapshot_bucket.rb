if Rails.env.production? && ActiveRecord::Base.connection.table_exists?('entity_snapshots')
  EntitySnapshot.create_bucket_if_needed!
end

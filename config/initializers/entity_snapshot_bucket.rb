if Rails.env.production? && ActiveRecord::Base.connection.table_exists?('entity_snapshots')
  begin
    EntitySnapshot.create_bucket_if_needed!
  rescue => e
    e.log_me
  end
end

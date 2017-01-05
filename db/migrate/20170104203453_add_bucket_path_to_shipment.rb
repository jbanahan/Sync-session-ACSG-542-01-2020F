class AddBucketPathToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :last_file_bucket, :string
    add_column :shipments, :last_file_path, :string
  end
end

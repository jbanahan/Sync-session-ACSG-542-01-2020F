class AddLastFileBucketAndLastFilePathToProducts < ActiveRecord::Migration
  def up
    add_column :products, :last_file_bucket, :string
    add_column :products, :last_file_path, :string
  end

  def down
    remove_column :products, :last_file_bucket
    remove_column :products, :last_file_path
  end
end

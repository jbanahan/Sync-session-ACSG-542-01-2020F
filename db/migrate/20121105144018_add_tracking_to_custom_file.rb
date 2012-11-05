class AddTrackingToCustomFile < ActiveRecord::Migration
  def self.up
    add_column :custom_files, :start_at, :datetime
    add_column :custom_files, :finish_at, :datetime
    add_column :custom_files, :error_at, :datetime
    add_column :custom_files, :error_message, :string
  end

  def self.down
    remove_column :custom_files, :error_message
    remove_column :custom_files, :error_at
    remove_column :custom_files, :finish_at
    remove_column :custom_files, :start_at
  end
end

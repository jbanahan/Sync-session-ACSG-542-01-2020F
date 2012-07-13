class AddSourceSystemTimestampToAttachment < ActiveRecord::Migration
  def self.up
    add_column :attachments, :source_system_timestamp, :datetime
    add_column :attachments, :alliance_suffix, :string
    add_column :attachments, :alliance_revision, :integer
  end

  def self.down
    remove_column :attachments, :alliance_revision
    remove_column :attachments, :alliance_suffix
    remove_column :attachments, :source_system_timestamp
  end
end

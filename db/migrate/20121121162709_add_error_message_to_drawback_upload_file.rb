class AddErrorMessageToDrawbackUploadFile < ActiveRecord::Migration
  def self.up
    add_column :drawback_upload_files, :error_message, :string
  end

  def self.down
    remove_column :drawback_upload_files, :error_message
  end
end

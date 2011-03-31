class AddDownloadFormatToSearchSetup < ActiveRecord::Migration
  def self.up
    add_column :search_setups, :download_format, :string
    add_column :search_schedules, :download_format, :string
  end

  def self.down
    remove_column :search_schedules, :download_format
    remove_column :search_setups, :download_format
  end
end

class AddReleaseStatusFieldsToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :paperless_release, :boolean
    add_column :entries, :error_free_release, :boolean
    add_column :entries, :census_warning, :boolean
    add_column :entries, :paperless_certification, :boolean
  end

  def self.down
    remove_column :entries, :census_warning
    remove_column :entries, :error_free_release
    remove_column :entries, :paperless_release
    remove_column :entries, :paperless_certification
  end
end

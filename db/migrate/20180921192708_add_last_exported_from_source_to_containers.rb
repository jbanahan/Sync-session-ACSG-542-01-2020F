class AddLastExportedFromSourceToContainers < ActiveRecord::Migration
  def change
    add_column :containers, :last_exported_from_source, :datetime
  end
end

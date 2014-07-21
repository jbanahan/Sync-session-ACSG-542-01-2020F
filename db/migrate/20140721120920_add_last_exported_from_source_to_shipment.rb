class AddLastExportedFromSourceToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :last_exported_from_source, :datetime
  end
end

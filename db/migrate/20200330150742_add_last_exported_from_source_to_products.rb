class AddLastExportedFromSourceToProducts < ActiveRecord::Migration
  def change
    add_column :products, :last_exported_from_source, :datetime
  end
end

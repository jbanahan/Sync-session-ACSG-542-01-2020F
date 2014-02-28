class AddParsingInformationToOrders < ActiveRecord::Migration
  def up
    change_table(:orders) do |t|
      t.column :importer_id, :integer
      t.column :customer_order_number, :string
      t.column :last_file_bucket, :string
      t.column :last_file_path, :string
      t.column :last_exported_from_source, :datetime
    end
    add_index :orders, :order_number
    add_index :orders, [:importer_id, :customer_order_number]
  end

  def down
    change_table(:orders) do |t|
      t.remove :importer_id
      t.remove :customer_order_number
      t.remove :last_file_bucket
      t.remove :last_file_path
      t.remove :last_exported_from_source
    end
    remove_index :orders, :order_number
  end
end

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

    change_table(:order_lines) do |t|
      t.column :item_identifier , :string
      t.column :quantity_uom, :string
    end
  end

  def down
    change_table(:orders) do |t|
      t.remove :importer_id
      t.remove :customer_order_number
    end
    change_table(:order_lines) do |t|
      t.remove :item_identifier
      t.remove :quantity_uom
    end
    remove_index :orders, :order_number
  end
end

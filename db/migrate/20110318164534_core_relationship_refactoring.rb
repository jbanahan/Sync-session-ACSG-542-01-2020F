class CoreRelationshipRefactoring < ActiveRecord::Migration
  def self.up
    remove_column :order_lines, :ordered_qty
    remove_column :order_lines, :product_id
    remove_column :sales_order_lines, :ordered_qty
    remove_column :sales_order_lines, :product_id
    remove_column :piece_sets, :shipment_id
    remove_column :piece_sets, :delivery_id
    create_table :shipment_lines do |t|
      t.integer :line_number
      t.timestamps
    end
    create_table :delivery_lines do |t|
      t.integer :line_number
      t.timestamps
    end
    add_column :piece_sets, :shipment_line_id, :integer
    add_column :piece_sets, :delivery_line_id, :integer
  end

  def self.down
    remove_column :piece_sets, :delivery_line_id
    remove_column :piece_sets, :shipment_line_id
    drop_table :delivery_lines
    drop_table :shipment_lines
    add_column :piece_sets, :delivery_id
    add_column :piece_sets, :shipment_id
    add_column :sales_order_lines, :product_id, :integer
    add_column :sales_order_lines, :ordered_qty, :decimal
    add_column :order_lines, :product_id, :integer
    add_column :order_lines, :ordered_qty, :decimal
  end
end

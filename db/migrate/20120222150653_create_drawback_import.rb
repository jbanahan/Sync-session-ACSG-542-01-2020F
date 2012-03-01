class CreateDrawbackImport < ActiveRecord::Migration
  def self.up
    create_table :drawback_import_lines do |t|
      t.decimal :quantity, :precision => 13, :scale => 4
      t.integer :product_id
      t.integer :line_number
      t.timestamps
    end
    add_index :drawback_import_lines, :product_id
    add_column :piece_sets, :drawback_import_line_id, :integer
    add_index :piece_sets, :drawback_import_line_id
    add_column :piece_sets, :commercial_invoice_line_id, :integer
    add_index :piece_sets, :commercial_invoice_line_id
  end

  def self.down
    remove_index :piece_sets, :commercial_invoice_line_id
    remove_column :piece_sets, :commercial_invoice_line_id
    remove_index :piece_sets, :drawback_import_line_id
    remove_column :piece_sets, :drawback_import_line_id
    remove_index :drawback_import_lines, :product_id
    drop_table :drawback_import_lines
  end
end

class CreateDrawbackAllocations < ActiveRecord::Migration
  def change
    create_table :drawback_allocations do |t|
      t.references :duty_calc_export_file_line
      t.references :drawback_import_line
      t.decimal :quantity, precision: 13, scale: 4

      t.timestamps
    end
    add_index :drawback_allocations, :duty_calc_export_file_line_id
    add_index :drawback_allocations, :drawback_import_line_id
  end
end

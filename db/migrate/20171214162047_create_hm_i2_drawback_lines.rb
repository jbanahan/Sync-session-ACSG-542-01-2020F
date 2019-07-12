class CreateHmI2DrawbackLines < ActiveRecord::Migration
  def up
    create_table(:hm_i2_drawback_lines) do |t|
      t.string :shipment_type
      t.string :invoice_number
      t.string :invoice_line_number
      t.datetime :shipment_date
      t.string :consignment_number
      t.string :consignment_line_number
      t.string :po_number
      t.string :po_line_number
      t.string :part_number
      t.string :part_description
      t.string :origin_country_code
      t.decimal :quantity, precision: 11, scale: 2
      t.string :carrier
      t.string :carrier_tracking_number
      t.string :customer_order_reference
      t.string :country_code
      t.string :return_reference_number
      t.decimal :item_value, precision: 11, scale: 2
      t.boolean :export_received
      t.datetime :converted_date

      t.timestamps
    end

    add_index :hm_i2_drawback_lines, [:invoice_number, :invoice_line_number], unique: true, name: "index_hm_i2_drawback_lines_on_invoice_and_line_number"
    add_index :hm_i2_drawback_lines, [:carrier_tracking_number]
    add_index :hm_i2_drawback_lines, [:shipment_date]

    change_table :drawback_import_lines, bulk:true do |t|
      t.date :liquidation_date
      t.string :ref_1
      t.string :ref_2
      t.string :country_of_export_code
    end
  end

  def down
    drop_table :hm_i2_drawback_lines
    remove_column :drawback_import_lines, :liquidation_date
    remove_column :drawback_import_lines, :ref_1
    remove_column :drawback_import_lines, :ref_2
    remove_column :drawback_import_lines, :country_of_export_code
  end
end
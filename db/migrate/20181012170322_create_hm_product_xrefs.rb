class CreateHmProductXrefs < ActiveRecord::Migration
  def up
    create_table(:hm_product_xrefs) do |t|
      t.string :sku
      t.string :color_description
      t.string :size_description

      t.timestamps
    end

    add_index :hm_product_xrefs, [:sku], unique: true, name: "index_hm_product_xref_on_sku"

    create_table(:hm_receipt_lines) do |t|
      t.string :location_code
      t.date :delivery_date
      t.string :ecc_variant_code
      t.string :order_number
      t.string :production_country
      t.integer :quantity
      t.string :sku
      t.string :season

      t.timestamps
    end

    add_index :hm_receipt_lines, [:order_number, :sku, :delivery_date], unique: true, name: "index_hm_receipt_lines_on_order_number_sku_delivery_date"

    change_table :duty_calc_export_file_lines, bulk:true do |t|
      t.string :color_description
      t.string :size_description
    end

    change_table :drawback_import_lines, bulk:true do |t|
      t.string :color_description
      t.string :size_description
      t.decimal :exchange_rate, :precision => 8, :scale => 6
      t.decimal :receipt_quantity, :precision => 8, :scale => 6
      t.decimal :hts_duty, :precision => 12, :scale => 2
      t.decimal :hts_quantity, :precision => 12, :scale => 2
      t.decimal :quantity_2, :precision => 12, :scale => 2
      t.integer :entered_value_7501
      t.decimal :total_taxes, :precision => 12, :scale => 2
      t.string :spi_primary
      t.integer :summary_line_count
    end
  end

  def down
    drop_table :hm_product_xrefs
    drop_table :hm_receipt_lines
    remove_column :duty_calc_export_file_lines, :color_description
    remove_column :duty_calc_export_file_lines, :size_description
    remove_column :drawback_import_lines, :color_description
    remove_column :drawback_import_lines, :size_description
    remove_column :drawback_import_lines, :exchange_rate
    remove_column :drawback_import_lines, :receipt_quantity
    remove_column :drawback_import_lines, :quantity_2
    remove_column :drawback_import_lines, :hts_duty
    remove_column :drawback_import_lines, :hts_quantity
    remove_column :drawback_import_lines, :entered_value_7501
    remove_column :drawback_import_lines, :total_taxes
    remove_column :drawback_import_lines, :spi_primary
    remove_column :drawback_import_lines, :summary_line_count
  end
end
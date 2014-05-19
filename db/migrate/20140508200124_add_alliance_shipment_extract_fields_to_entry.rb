class AddAllianceShipmentExtractFieldsToEntry < ActiveRecord::Migration
  def change
    change_table :entries do |t|
      t.date :final_statement_date
      t.string :bond_type
      t.string :location_of_goods
    end

    change_table :commercial_invoice_lines do |t|
      t.integer :customs_line_number
      t.string :product_line
      t.string :visa_number
      t.decimal :visa_quantity, precision: 12, scale: 3
      t.string :visa_uom
    end

    add_column :commercial_invoice_tariffs, :quota_category, :integer
  end
end

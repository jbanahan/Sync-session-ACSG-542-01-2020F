class AddCommercialInvoiceLaceyComponent < ActiveRecord::Migration
  def change
    create_table :commercial_invoice_lacey_components do |t|
      t.integer :line_number
      t.string :detailed_description
      t.decimal :value, precision: 9, scale: 2
      t.string :name
      t.decimal :quantity, precision: 12, scale: 3
      t.string :unit_of_measure
      t.string :genus
      t.string :species
      t.string :harvested_from_country
      t.decimal :percent_recycled_material, precision: 5, scale: 2
      t.string :container_numbers
      t.references :commercial_invoice_tariff, index: true, null: false
    end

    add_index :commercial_invoice_lacey_components, :commercial_invoice_tariff_id, name: "lacey_components_by_tariff_id"
  end

end

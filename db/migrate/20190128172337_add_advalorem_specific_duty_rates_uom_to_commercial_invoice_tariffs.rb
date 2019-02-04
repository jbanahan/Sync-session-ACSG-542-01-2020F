class AddAdvaloremSpecificDutyRatesUomToCommercialInvoiceTariffs < ActiveRecord::Migration
  def up
    change_table(:commercial_invoice_tariffs, bulk: true) do |t|
      t.decimal :advalorem_rate, precision: 14, scale: 7
      t.decimal :specific_rate, precision: 14, scale: 7
      t.string :specific_rate_uom
      t.decimal :additional_rate, precision: 14, scale: 7
      t.string :additional_rate_uom
    end
  end

  def down
    change_table(:commercial_invoice_tariffs, bulk: true) do |t|
      t.remove :advalorem_rate
      t.remove :specific_rate
      t.remove :specific_rate_uom
      t.remove :additional_rate
      t.remove :additional_rate_uom
    end
  end
end

class AddDutyFieldsToCommercialInvoiceTariffs < ActiveRecord::Migration
  def up
    change_table(:commercial_invoice_tariffs, bulk: true) do |t|
      t.decimal :duty_advalorem, precision: 12, scale: 2
      t.decimal :duty_specific, precision: 12, scale: 2
      t.decimal :duty_additional, precision: 12, scale: 2
      t.decimal :duty_other, precision: 12, scale: 2
    end
  end
end

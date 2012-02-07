class AddFenixFieldsToCommercialInvoiceTariff < ActiveRecord::Migration
  def self.up
    add_column :commercial_invoice_tariffs, :tariff_provision, :string
    add_column :commercial_invoice_tariffs, :value_for_duty_code, :string
  end

  def self.down
    remove_column :commercial_invoice_tariffs, :value_for_duty_code
    remove_column :commercial_invoice_tariffs, :tariff_provision
  end
end

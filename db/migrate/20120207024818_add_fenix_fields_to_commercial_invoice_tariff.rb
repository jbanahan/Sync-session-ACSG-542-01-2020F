class AddFenixFieldsToCommercialInvoiceTariff < ActiveRecord::Migration
  def self.up
    add_column :commercial_invoice_tariffs, :tariff_provision, :string
    add_column :commercial_invoice_tariffs, :value_for_duty_code, :string
    add_column :commercial_invoice_tariffs, :gst_rate_code, :string
    add_column :commercial_invoice_tariffs, :gst_amount, :decimal, :precision=>11, :scale=>2
    add_column :commercial_invoice_tariffs, :sima_amount, :decimal, :precision=>11, :scale=>2
    add_column :commercial_invoice_tariffs, :excise_amount, :decimal, :precision=>11, :scale=>2
    add_column :commercial_invoice_tariffs, :excise_rate_code, :string
  end

  def self.down
    remove_column :commercial_invoice_tariffs, :excise_rate_code
    remove_column :commercial_invoice_tariffs, :excise_amount
    remove_column :commercial_invoice_tariffs, :sima_amount
    remove_column :commercial_invoice_tariffs, :gst_amount
    remove_column :commercial_invoice_tariffs, :gst_rate_code
    remove_column :commercial_invoice_tariffs, :value_for_duty_code
    remove_column :commercial_invoice_tariffs, :tariff_provision
  end
end

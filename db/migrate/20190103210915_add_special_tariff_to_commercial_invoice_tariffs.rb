class AddSpecialTariffToCommercialInvoiceTariffs < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_tariffs, :special_tariff, :boolean
  end
end

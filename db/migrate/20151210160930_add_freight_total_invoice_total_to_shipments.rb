class AddFreightTotalInvoiceTotalToShipments < ActiveRecord::Migration
  def change
    add_column :shipments, :freight_total, :decimal, precision: 11, scale: 2
    add_column :shipments, :invoice_total, :decimal, precision: 11, scale: 2
  end
end

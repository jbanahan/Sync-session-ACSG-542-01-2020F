class AddInvoiceNumberToShipmentLine < ActiveRecord::Migration
  def change
    add_column :shipment_lines, :invoice_number, :string
  end
end

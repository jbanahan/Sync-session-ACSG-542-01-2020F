class AddSimaCodeToCommercialInvoiceTariffs < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_tariffs, :sima_code, :string
  end
end

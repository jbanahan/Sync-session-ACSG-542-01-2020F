class AddSpecialAuthorityToCommercialInvoiceTariffs < ActiveRecord::Migration
  def change
    add_column :commercial_invoice_tariffs, :special_authority, :string
  end
end

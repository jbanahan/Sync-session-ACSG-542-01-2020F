class AddConsigneeIdToCommercialInvoices < ActiveRecord::Migration
  def change
    add_column :commercial_invoices, :consignee_id, :integer
  end
end

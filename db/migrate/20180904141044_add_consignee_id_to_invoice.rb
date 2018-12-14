class AddConsigneeIdToInvoice < ActiveRecord::Migration
  def change
    add_column :invoices, :consignee_id, :integer
  end
end

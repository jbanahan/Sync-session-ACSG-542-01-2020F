class AddCommercialInvoiceIdToItemChangeSubscription < ActiveRecord::Migration
  def self.up
    add_column :item_change_subscriptions, :commercial_invoice_id, :integer
  end

  def self.down
    remove_column :item_change_subscriptions, :commercial_invoice_id
  end
end

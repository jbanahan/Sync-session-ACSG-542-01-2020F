class AddCompanyIdToItemChangeSubscriptions < ActiveRecord::Migration
  def change
    add_column :item_change_subscriptions, :company_id, :integer
    add_index :item_change_subscriptions, :company_id
  end
end

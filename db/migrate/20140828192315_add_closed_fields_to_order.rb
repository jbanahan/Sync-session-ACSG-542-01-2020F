class AddClosedFieldsToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :closed_at, :datetime
    add_column :orders, :closed_by_id, :integer
    add_index :orders, :closed_at
    add_index :orders, :closed_by_id
  end
end

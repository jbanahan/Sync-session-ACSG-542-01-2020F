class AddAcceptByAndDateToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :accepted_by_id, :integer
    add_column :orders, :accepted_at, :datetime
    add_index :orders, :accepted_by_id
    add_index :orders, :accepted_at
  end
end

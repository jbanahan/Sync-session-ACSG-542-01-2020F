class AddCancelToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :canceled_date, :date
    add_column :shipments, :canceled_by_id, :integer
    add_index :shipments, :canceled_date
    add_index :shipments, :canceled_by_id
  end
end

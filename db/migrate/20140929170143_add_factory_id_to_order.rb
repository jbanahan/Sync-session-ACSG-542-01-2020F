class AddFactoryIdToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :factory_id, :integer
    add_index :orders, :factory_id
  end
end

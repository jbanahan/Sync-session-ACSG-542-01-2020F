class AddDescriptionOfGoodsToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :description_of_goods, :string
  end
end

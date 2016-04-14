class AddLocationOfGoodsDescriptionToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :location_of_goods_description, :string
  end
end

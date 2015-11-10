class AddVariantEditToUser < ActiveRecord::Migration
  def change
    add_column :users, :variant_edit, :boolean
  end
end

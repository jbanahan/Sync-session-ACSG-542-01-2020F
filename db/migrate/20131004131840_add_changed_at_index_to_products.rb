class AddChangedAtIndexToProducts < ActiveRecord::Migration

  def up
    add_index :products, :changed_at
  end

  def down
    if index_exists? :products, :changed_at
      remove_index :products, :changed_at
    end
  end
end

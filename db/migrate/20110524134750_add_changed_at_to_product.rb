class AddChangedAtToProduct < ActiveRecord::Migration
  def self.up
    add_column :products, :changed_at, :datetime
    execute "update products set changed_at = updated_at where changed_at is null;"
  end

  def self.down
    remove_column :products, :changed_at
  end
end

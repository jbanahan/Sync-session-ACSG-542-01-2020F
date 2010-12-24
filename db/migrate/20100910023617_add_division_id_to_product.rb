class AddDivisionIdToProduct < ActiveRecord::Migration
  def self.up
		add_column :products, :division_id, :integer
  end

  def self.down
		remove_column :products, :division_id
  end
end

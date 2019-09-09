class AddPortIdToAddresses < ActiveRecord::Migration
  def up
    add_column :addresses, :port_id, :integer
    add_index :addresses, :port_id
  end

  def down
    remove_column :addresses, :port_id
  end
end

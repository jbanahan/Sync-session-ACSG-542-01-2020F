class AddCodesToPort < ActiveRecord::Migration
  def self.up
    add_column :ports, :cbsa_port, :string
    add_column :ports, :cbsa_sublocation, :string
    add_column :ports, :unlocode, :string
    add_index :ports, :cbsa_port
    add_index :ports, :cbsa_sublocation
    add_index :ports, :unlocode
  end

  def self.down
    remove_index :ports, :cbsa_port
    remove_index :ports, :cbsa_sublocation
    remove_index :ports, :unlocode
    remove_column :ports, :unlocode
    remove_column :ports, :cbsa_sublocation
    remove_column :ports, :cbsa_port
  end
end

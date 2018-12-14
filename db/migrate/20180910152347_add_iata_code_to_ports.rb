class AddIataCodeToPorts < ActiveRecord::Migration
  def up
    add_column :ports, :iata_code, :string

    add_index :ports, :iata_code
  end

  def down
    remove_column :ports, :iata_code
  end
end

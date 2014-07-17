class AddAddressHashToAddress < ActiveRecord::Migration
  def change
    add_column :addresses, :address_hash, :string
    add_column :addresses, :system_code, :string
    add_index :addresses, :address_hash
    add_index :addresses, :system_code
  end
end

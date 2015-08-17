class AddInAddressBookToAddress < ActiveRecord::Migration
  def change
    add_column :addresses, :in_address_book, :boolean
  end
end

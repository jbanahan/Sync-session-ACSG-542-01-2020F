class AddPhoneAndFaxToAddresses < ActiveRecord::Migration
  def change
    add_column :addresses, :phone_number, :string
    add_column :addresses, :fax_number, :string
  end
end

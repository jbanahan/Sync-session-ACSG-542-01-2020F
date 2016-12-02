class AddForwarderToCompany < ActiveRecord::Migration
  def change
    add_column :companies, :forwarder, :boolean
  end
end

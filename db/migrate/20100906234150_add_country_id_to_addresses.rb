class AddCountryIdToAddresses < ActiveRecord::Migration
  def self.up
		add_column :addresses, :country_id, :integer
	end

  def self.down
  end
end

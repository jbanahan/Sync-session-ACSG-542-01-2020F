class AddTicketingSystemCodeToCompanies < ActiveRecord::Migration
  def self.up
    add_column :companies, :ticketing_system_code, :string
  end

  def self.down
    remove_column :companies, :ticketing_system_code
  end
end

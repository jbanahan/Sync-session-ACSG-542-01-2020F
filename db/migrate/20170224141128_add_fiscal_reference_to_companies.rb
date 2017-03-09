class AddFiscalReferenceToCompanies < ActiveRecord::Migration
  def self.up
    add_column :companies, :fiscal_reference, :string
  end

  def self.down
    remove_column :companies, :fiscal_reference
  end
end

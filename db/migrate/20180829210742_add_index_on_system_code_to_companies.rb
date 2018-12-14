class AddIndexOnSystemCodeToCompanies < ActiveRecord::Migration
  def change
    add_index :companies, :system_code
  end
end

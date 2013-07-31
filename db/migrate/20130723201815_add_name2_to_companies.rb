class AddName2ToCompanies < ActiveRecord::Migration
  def change
    add_column :companies, :name_2, :string
  end
end

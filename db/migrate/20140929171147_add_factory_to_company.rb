class AddFactoryToCompany < ActiveRecord::Migration
  def change
    add_column :companies, :factory, :boolean
    add_index :companies, :factory
  end
end

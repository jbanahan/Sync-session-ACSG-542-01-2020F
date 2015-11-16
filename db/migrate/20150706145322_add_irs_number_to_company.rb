class AddIrsNumberToCompany < ActiveRecord::Migration
  def change
    add_column :companies, :irs_number, :string
  end
end

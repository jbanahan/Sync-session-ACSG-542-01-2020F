class AddReliquidationDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :reliquidation_date, :datetime
  end
end

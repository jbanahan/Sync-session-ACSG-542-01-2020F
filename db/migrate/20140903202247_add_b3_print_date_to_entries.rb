class AddB3PrintDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :b3_print_date, :datetime
  end
end

class AddPartNumbersToEntry < ActiveRecord::Migration
  def change
    add_column :entries, :part_numbers, :text
  end
end

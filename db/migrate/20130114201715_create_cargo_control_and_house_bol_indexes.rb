class CreateCargoControlAndHouseBolIndexes < ActiveRecord::Migration
  def up
      add_index :entries, :house_bills_of_lading, :length => 64
      add_index :entries, :cargo_control_number
  end

  def down

    remove_index(:entries, :column=>:house_bills_of_lading) if index_exists?(:entries, :house_bills_of_lading)
    remove_index(:entries, :column=>:cargo_control_number) if index_exists?(:entries, :cargo_control_number)
  end
end

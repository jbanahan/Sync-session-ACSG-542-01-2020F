class Add7501PrintDatesToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :first_7501_print, :datetime
    add_column :entries, :last_7501_print, :datetime
  end

  def self.down
    remove_column :entries, :last_7501_print
    remove_column :entries, :first_7501_print
  end
end

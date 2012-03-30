class AddChargeCodesToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :charge_codes, :string
  end

  def self.down
    remove_column :entries, :charge_codes
  end
end

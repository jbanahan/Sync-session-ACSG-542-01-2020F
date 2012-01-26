class AddVesselVoyageToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :vessel, :string
    add_column :entries, :voyage, :string
  end

  def self.down
    remove_column :entries, :voyage
    remove_column :entries, :vessel
  end
end

class AddReconFlagsToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :recon_flags, :string
  end

  def self.down
    remove_column :entries, :recon_flags
  end
end

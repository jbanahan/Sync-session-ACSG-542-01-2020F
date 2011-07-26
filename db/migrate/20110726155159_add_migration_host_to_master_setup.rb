class AddMigrationHostToMasterSetup < ActiveRecord::Migration
  def self.up
    add_column :master_setups, :migration_host, :string
  end

  def self.down
    remove_column :master_setups, :migration_host
  end
end

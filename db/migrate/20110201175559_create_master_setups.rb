class CreateMasterSetups < ActiveRecord::Migration
  def self.up
    create_table :master_setups do |t|
      t.string :uuid

      t.timestamps
    end
  end

  def self.down
    drop_table :master_setups
  end
end

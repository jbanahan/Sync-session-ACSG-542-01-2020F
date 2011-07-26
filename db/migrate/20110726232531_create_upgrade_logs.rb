class CreateUpgradeLogs < ActiveRecord::Migration
  def self.up
    create_table :upgrade_logs do |t|
      t.string :from_version
      t.string :to_version
      t.datetime :started_at
      t.datetime :finished_at
      t.text :log
      t.integer :instance_information_id

      t.timestamps
    end
  end

  def self.down
    drop_table :upgrade_logs
  end
end

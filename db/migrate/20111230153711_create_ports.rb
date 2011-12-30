class CreatePorts < ActiveRecord::Migration
  def self.up
    create_table :ports do |t|
      t.string :schedule_d_code
      t.string :schedule_k_code
      t.string :name

      t.timestamps
    end
    add_index :ports, :schedule_d_code
    add_index :ports, :schedule_k_code
  end

  def self.down
    drop_table :ports
  end
end

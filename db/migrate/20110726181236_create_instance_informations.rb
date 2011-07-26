class CreateInstanceInformations < ActiveRecord::Migration
  def self.up
    create_table :instance_informations do |t|
      t.string :host
      t.datetime :last_check_in
      t.string :version

      t.timestamps
    end
  end

  def self.down
    drop_table :instance_informations
  end
end

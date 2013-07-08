class CreateLocks < ActiveRecord::Migration
  def up
    create_table :locks do |t|
      t.string :name, :limit => 40
      t.timestamps
    end
    add_index :locks, :name, :unique => true
  end

  def down
    drop_table :locks
  end
end

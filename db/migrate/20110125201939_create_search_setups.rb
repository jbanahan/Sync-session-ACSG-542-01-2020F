class CreateSearchSetups < ActiveRecord::Migration
  def self.up
    create_table :search_setups do |t|
      t.string :name
      t.integer :user_id
      t.string :module_type
      t.boolean :simple
      t.datetime :last_accessed

      t.timestamps
    end
  end

  def self.down
    drop_table :search_setups
  end
end

class CreateStatusRules < ActiveRecord::Migration
  def self.up
    create_table :status_rules do |t|
      t.string :module_type
      t.string :name
      t.string :description
      t.integer :test_rank

      t.timestamps
    end
  end

  def self.down
    drop_table :status_rules
  end
end

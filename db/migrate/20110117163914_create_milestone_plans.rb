class CreateMilestonePlans < ActiveRecord::Migration
  def self.up
    create_table :milestone_plans do |t|
      t.string :name
      t.integer :test_rank

      t.timestamps
    end
  end

  def self.down
    drop_table :milestone_plans
  end
end

class RemoveMilestonePlans < ActiveRecord::Migration
  def self.up
    drop_table :milestone_plans
    remove_column :search_criterions, :milestone_plan_id
  end

  def self.down
    add_column :search_criterions, :milestone_plan_id, :integer
    create_table :milestone_plans do |t|
      t.string :name
      t.integer :test_rank
      t.boolean :inbound

      t.timestamps
    end
  end
end

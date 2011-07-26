class AddDisplayRankToMilestoneDefinition < ActiveRecord::Migration
  def self.up
    add_column :milestone_definitions, :display_rank, :integer
  end

  def self.down
    remove_column :milestone_definitions, :display_rank
  end
end

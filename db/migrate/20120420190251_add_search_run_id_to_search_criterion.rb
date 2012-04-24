class AddSearchRunIdToSearchCriterion < ActiveRecord::Migration
  def self.up
    add_column :search_criterions, :search_run_id, :integer
    add_index :search_criterions, :search_run_id
  end

  def self.down
    remove_column :search_criterions, :search_run_id
  end
end

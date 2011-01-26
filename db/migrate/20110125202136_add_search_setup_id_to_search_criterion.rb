class AddSearchSetupIdToSearchCriterion < ActiveRecord::Migration
  def self.up
    add_column :search_criterions, :search_setup_id, :integer
  end

  def self.down
    remove_column :search_criterions, :search_setup_id
  end
end

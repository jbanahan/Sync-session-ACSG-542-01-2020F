class AddStateToggleButtonIdToSearchCriterion < ActiveRecord::Migration
  def change
    add_column :search_criterions, :state_toggle_button_id, :integer
    add_index :search_criterions, :state_toggle_button_id
  end
end

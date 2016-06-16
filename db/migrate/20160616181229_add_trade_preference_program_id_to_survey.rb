class AddTradePreferenceProgramIdToSurvey < ActiveRecord::Migration
  def change
    add_column :surveys, :trade_preference_program_id, :integer
    add_index :surveys, :trade_preference_program_id, name: 'tpp_id'
  end
end

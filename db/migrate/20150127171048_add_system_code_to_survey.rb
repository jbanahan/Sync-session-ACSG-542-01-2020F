class AddSystemCodeToSurvey < ActiveRecord::Migration
  def change
    add_column :surveys, :system_code, :string
    add_index :surveys, :system_code
  end
end

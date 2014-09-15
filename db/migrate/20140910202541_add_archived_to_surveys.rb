class AddArchivedToSurveys < ActiveRecord::Migration
  def change
    add_column :surveys, :archived, :boolean, default: false
    execute "UPDATE surveys SET archived = 0"
  end
end

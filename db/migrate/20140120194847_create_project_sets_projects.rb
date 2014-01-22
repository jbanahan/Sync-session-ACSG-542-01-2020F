class CreateProjectSetsProjects < ActiveRecord::Migration
  def change
    create_table :project_sets_projects, id: false do |t|
    t.belongs_to :project_set, null: false
    t.belongs_to :project, null: false
    end
    add_index :project_sets_projects, [:project_set_id, :project_id], unique: true
    add_index :project_sets_projects, [:project_id, :project_set_id], unique: true
  end
end

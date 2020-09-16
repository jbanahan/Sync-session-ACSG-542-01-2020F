class RemoveProjectTables < ActiveRecord::Migration
  def change
    # rubocop:disable Rails/ReversibleMigration
    drop_table :project_deliverables
    drop_table :project_sets
    drop_table :project_sets_projects
    drop_table :project_updates
    drop_table :projects
    # rubocop:enable Rails/ReversibleMigration
  end
end

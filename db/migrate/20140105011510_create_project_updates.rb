class CreateProjectUpdates < ActiveRecord::Migration
  def change
    create_table :project_updates do |t|
      t.references :project
      t.integer :created_by_id
      t.text :body

      t.timestamps
    end
    add_index :project_updates, :project_id
    add_index :project_updates, :created_by_id
  end
end

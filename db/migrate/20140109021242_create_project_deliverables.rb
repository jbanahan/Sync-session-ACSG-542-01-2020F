class CreateProjectDeliverables < ActiveRecord::Migration
  def change
    create_table :project_deliverables do |t|
      t.references :project
      t.text :description
      t.references :assigned_to
      t.date :start_date
      t.date :end_date
      t.date :due_date
      t.integer :estimated_hours
      t.boolean :complete

      t.timestamps
    end
    add_index :project_deliverables, :project_id
    add_index :project_deliverables, :assigned_to_id
  end
end

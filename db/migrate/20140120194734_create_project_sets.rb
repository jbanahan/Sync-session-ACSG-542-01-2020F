class CreateProjectSets < ActiveRecord::Migration
  def change
    create_table :project_sets do |t|
      t.string :name

      t.timestamps null: false
    end
    add_index :project_sets, :name, unique: true
  end
end

class CreateFolders < ActiveRecord::Migration
  def up
    create_table :folders do |t|
      t.string :name
      t.references :base_object, polymorphic: true, null: false
      t.references :created_by, null: false

      t.timestamps null: false
    end

    add_index :folders, [:base_object_id, :base_object_type]
    add_index :folders, [:created_by_id]

    create_table :folder_groups do |t|
      t.integer :folder_id
      t.integer :group_id
    end

    add_index :folder_groups, [:folder_id]
  end

  def down
    drop_table :folder_groups
    drop_table :folders
  end
end

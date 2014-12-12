class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.string :system_code
      t.string :name
      t.string :description

      t.timestamps
    end

    add_index :groups, :system_code, unique: true

    create_table :user_group_memberships do |t|
      t.references :group
      t.references :user
    end

    add_index :user_group_memberships, :group_id
    add_index :user_group_memberships, [:user_id, :group_id], unique: true
  end

end

class CreateSystemIdentifiers < ActiveRecord::Migration
  def up
    create_table(:system_identifiers) do |t|
      t.integer :company_id
      t.string :system, null: false
      t.string :code, null: false

      t.timestamps
    end

    add_index :system_identifiers, [:system, :code], unique: true
    add_index :system_identifiers, [:company_id, :system]
  end

  def down
    drop_table(:system_identifiers)
  end
end

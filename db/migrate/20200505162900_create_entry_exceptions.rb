class CreateEntryExceptions < ActiveRecord::Migration
  def self.up
    create_table :entry_exceptions do |t|
      t.integer :entry_id, null: false
      t.string :code, null: false
      t.text :comments
      t.datetime :resolved_date

      t.timestamps
    end

    add_index(:entry_exceptions, [:entry_id])
  end

  def self.down
    drop_table :entry_exceptions
  end
end

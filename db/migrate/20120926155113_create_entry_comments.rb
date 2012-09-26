class CreateEntryComments < ActiveRecord::Migration
  def self.up
    create_table :entry_comments do |t|
      t.integer :entry_id
      t.text :body
      t.datetime :generated_at
      t.string :username

      t.timestamps
    end
    add_index :entry_comments, :entry_id
  end

  def self.down
    drop_table :entry_comments
  end
end

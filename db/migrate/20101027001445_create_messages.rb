class CreateMessages < ActiveRecord::Migration
  def self.up
    create_table :messages do |t|
      t.string :user_id
      t.string :subject
      t.string :body
      t.string :folder, :default => 'inbox'
      t.boolean :read, :default => false
      t.string :link_name
      t.string :link_path

      t.timestamps
    end
  end

  def self.down
    drop_table :messages
  end
end

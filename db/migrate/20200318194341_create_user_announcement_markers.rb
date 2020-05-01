class CreateUserAnnouncementMarkers < ActiveRecord::Migration
  def change
    create_table :user_announcement_markers do |t|
      t.references :user
      t.references :announcement
      t.datetime :confirmed_at
      t.boolean :hidden

      t.timestamps
    end
    add_index :user_announcement_markers, [:user_id, :announcement_id]
  end
end

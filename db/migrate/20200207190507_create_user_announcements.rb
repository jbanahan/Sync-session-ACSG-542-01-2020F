class CreateUserAnnouncements < ActiveRecord::Migration
  def change
    create_table :user_announcements do |t|
      t.references :user
      t.references :announcement

      t.timestamps
    end
    add_index :user_announcements, [:user_id, :announcement_id]
  end
end

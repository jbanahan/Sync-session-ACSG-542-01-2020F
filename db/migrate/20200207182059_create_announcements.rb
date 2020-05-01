class CreateAnnouncements < ActiveRecord::Migration
  def change
    create_table :announcements do |t|
      t.string :title
      t.string :category
      # equivalent to MySQL mediumtext type
      t.text :text, limit: 16.megabytes - 1
      t.text :comments
      t.datetime :start_at
      t.datetime :end_at

      t.timestamps null: false
    end
  end
end

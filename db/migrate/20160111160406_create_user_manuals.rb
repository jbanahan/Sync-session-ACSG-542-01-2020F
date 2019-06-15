class CreateUserManuals < ActiveRecord::Migration
  def change
    create_table :user_manuals do |t|
      t.string :name
      t.string :page_url_regex
      t.text :groups

      t.timestamps null: false
    end
  end
end

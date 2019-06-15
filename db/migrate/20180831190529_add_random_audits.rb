class AddRandomAudits < ActiveRecord::Migration
  def up
    create_table :random_audits do |t|
      t.integer :user_id
      t.integer :search_setup_id
      t.string :attached_content_type
      t.integer :attached_file_size
      t.string :attached_file_name
      t.datetime :attached_updated_at
      t.string :module_type
      t.string :report_name
      t.datetime :report_date

      t.timestamps null: false
    end
  end

  def down
    drop_table :random_audits
  end
end

class CreateOneTimeAlerts < ActiveRecord::Migration
  def self.up
    create_table :one_time_alerts do |t|
      t.integer :user_id
      t.integer :expire_date_last_updated_by_id
      t.integer :mailing_list_id
      t.string :name
      t.string :module_type
      t.text :email_addresses
      t.string :email_subject
      t.text :email_body
      t.boolean :blind_copy_me
      t.date :enabled_date
      t.date :expire_date

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :one_time_alerts
  end
end

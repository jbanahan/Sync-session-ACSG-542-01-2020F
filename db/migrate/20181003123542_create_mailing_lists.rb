class CreateMailingLists < ActiveRecord::Migration
  def up
    create_table :mailing_lists do |t|
      t.string :system_code, null: false
      t.string :name
      t.timestamps null: false
      t.integer :user_id
      t.integer :company_id
      t.text :email_addresses
      t.boolean :non_vfi_addresses
    end

    add_index :mailing_lists, :system_code, unique: true
  end

  def down
    drop_table :mailing_lists
  end
end

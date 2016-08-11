class CreateSearchTableConfigs < ActiveRecord::Migration
  def change
    create_table :search_table_configs do |t|
      t.string :page_uid
      t.string :name
      t.text :config_json
      t.integer :user_id
      t.integer :company_id

      t.timestamps
    end
    add_index :search_table_configs, :page_uid
    add_index :search_table_configs, :user_id
    add_index :search_table_configs, :company_id
  end
end

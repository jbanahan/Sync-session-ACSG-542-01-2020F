class CreateKeyJsonItems < ActiveRecord::Migration
  def change
    create_table :key_json_items do |t|
      t.string :key_scope
      t.string :logical_key
      t.text :json_data
    end
    add_index :key_json_items, [:key_scope,:logical_key], {:name=>'scoped_logical_keys',:unique=>true}
  end
end

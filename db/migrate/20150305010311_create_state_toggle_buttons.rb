class CreateStateToggleButtons < ActiveRecord::Migration
  def change
    create_table :state_toggle_buttons do |t|
      t.string :module_type
      t.string :user_attribute
      t.integer :user_custom_definition_id
      t.string :date_attribute
      t.integer :date_custom_definition_id
      t.text :permission_group_system_codes
      t.string :activate_text
      t.string :activate_confirmation_text
      t.string :deactivate_text
      t.string :deactivate_confirmation_text

      t.timestamps
    end
    add_index :state_toggle_buttons, :module_type
    add_index :state_toggle_buttons, :updated_at #for cache expiration lookup
  end
end

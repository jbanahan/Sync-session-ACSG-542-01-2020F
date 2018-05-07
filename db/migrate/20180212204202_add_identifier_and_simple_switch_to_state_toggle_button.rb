class AddIdentifierAndSimpleSwitchToStateToggleButton < ActiveRecord::Migration
  def up
    change_table :state_toggle_buttons, bulk:true do |t|
      t.string :identifier
      t.boolean :simple_button
      t.integer :display_index
      t.boolean :disabled
    end

    add_index :state_toggle_buttons, :identifier, unique: true
    add_index :state_toggle_buttons, :display_index
  end

  def down
    remove_column :state_toggle_buttons, :identifier
    remove_column :state_toggle_buttons, :simple_button
    remove column :state_toggle_buttons, :display_index
    remove_column :state_toggle_buttons, :disabled
  end
end

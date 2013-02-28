class AddMessageCountIndex < ActiveRecord::Migration
  def change
    add_index :messages, [:user_id,:viewed]
  end
end

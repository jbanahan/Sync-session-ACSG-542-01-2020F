class AddNameIndexToPort < ActiveRecord::Migration
  def change
    add_index :ports, :name
  end
end

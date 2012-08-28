class AddDestinationStateToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :destination_state, :string
  end

  def self.down
    remove_column :entries, :destination_state
  end
end

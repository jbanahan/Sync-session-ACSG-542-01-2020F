class ChangeMessageUserIdToInteger < ActiveRecord::Migration
  def self.up
    change_column :messages, :user_id, :integer
  end

  def self.down
    change_column :messages, :user_id, :string
  end
end

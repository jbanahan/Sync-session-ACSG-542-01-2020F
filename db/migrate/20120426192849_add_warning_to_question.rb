class AddWarningToQuestion < ActiveRecord::Migration
  def self.up
    add_column :questions, :warning, :boolean
  end

  def self.down
    remove_column :questions, :warning
  end
end

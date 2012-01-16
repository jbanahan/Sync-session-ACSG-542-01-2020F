class AddSourceSystemToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :source_system, :string
  end

  def self.down
    remove_column :entries, :source_system
  end
end

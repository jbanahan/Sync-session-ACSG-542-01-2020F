class AddTimeToProcessToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :time_to_process, :integer
  end

  def self.down
    remove_column :entries, :time_to_process
  end
end

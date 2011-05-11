class AddFailedToChangeRecords < ActiveRecord::Migration
  def self.up
    add_column :change_records, :failed, :boolean
  end

  def self.down
    remove_column :change_records, :failed
  end
end

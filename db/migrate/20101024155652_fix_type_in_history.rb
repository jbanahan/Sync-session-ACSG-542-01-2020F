class FixTypeInHistory < ActiveRecord::Migration
  def self.up
    remove_column :histories, :type
    add_column    :histories, :history_type, :string
  end

  def self.down
    remove_column :histories, :history_type
    add_column    :histories, :type, :string
  end
end

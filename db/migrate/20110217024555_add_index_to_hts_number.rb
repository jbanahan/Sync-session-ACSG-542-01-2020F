class AddIndexToHtsNumber < ActiveRecord::Migration
  def self.up
    add_index :official_tariffs, :hts_code
  end

  def self.down
    remove_index :official_tariffs, :hts_code
  end
end

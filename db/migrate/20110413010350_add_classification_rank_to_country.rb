class AddClassificationRankToCountry < ActiveRecord::Migration
  def self.up
    add_column :countries, :classification_rank, :integer
  end

  def self.down
    remove_column :countries, :classification_rank
  end
end

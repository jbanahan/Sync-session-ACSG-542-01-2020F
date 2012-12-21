class ChangeValueColumnDatatypeToTextInSearchCriterions < ActiveRecord::Migration
  def self.up
    change_column :search_criterions, :value, :text
  end

  def self.down
    change_column :search_criterions, :value, :string
  end
end

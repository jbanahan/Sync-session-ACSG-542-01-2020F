class AddUpdatedAtIndexToEntry < ActiveRecord::Migration
  def change
    add_index :entries, :updated_at
  end
end

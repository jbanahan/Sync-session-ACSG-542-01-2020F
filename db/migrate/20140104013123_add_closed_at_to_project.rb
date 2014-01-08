class AddClosedAtToProject < ActiveRecord::Migration
  def change
    add_column :projects, :closed_at, :datetime
    add_index :projects, :closed_at
  end
end

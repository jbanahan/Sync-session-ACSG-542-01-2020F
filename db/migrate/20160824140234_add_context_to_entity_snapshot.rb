class AddContextToEntitySnapshot < ActiveRecord::Migration
  def up
    add_column :entity_snapshots, :context, :string
  end

  def down
    remove_column :entity_snapshots, :context
  end
end

class AddContainerIdToHistory < ActiveRecord::Migration
  def change
    add_column :histories, :container_id, :integer
    add_index  :histories, :container_id
  end
end

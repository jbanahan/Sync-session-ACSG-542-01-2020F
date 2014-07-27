class AddJJillFieldsToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :last_revised_date, :date
    add_column :orders, :agent_id, :integer
    add_column :orders, :approval_status, :string
    add_index :orders, :agent_id
    add_index :orders, :approval_status
  end
end

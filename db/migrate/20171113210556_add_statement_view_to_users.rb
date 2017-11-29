class AddStatementViewToUsers < ActiveRecord::Migration
  def change
    add_column :users, :statement_view, :boolean
  end
end

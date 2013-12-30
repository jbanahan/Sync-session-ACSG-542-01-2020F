class AddK84DueDateToEntry < ActiveRecord::Migration
  def change
    add_column :entries, :k84_due_date, :date
    add_index :entries, :k84_due_date
  end
end

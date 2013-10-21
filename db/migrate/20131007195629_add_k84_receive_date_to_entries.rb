class AddK84ReceiveDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :k84_receive_date, :date
  end
end

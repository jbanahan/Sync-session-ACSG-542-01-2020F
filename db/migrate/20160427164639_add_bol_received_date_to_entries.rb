class AddBolReceivedDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :bol_received_date, :datetime
  end
end

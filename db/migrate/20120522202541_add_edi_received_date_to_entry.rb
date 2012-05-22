class AddEdiReceivedDateToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :edi_received_date, :date
  end

  def self.down
    remove_column :entries, :edi_received_date
  end
end

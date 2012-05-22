class AddTicket559DatesToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :isf_sent_date, :datetime
    add_column :entries, :isf_accepted_date, :datetime
    add_column :entries, :docs_received_date, :date
    add_column :entries, :trucker_called_date, :datetime
  end

  def self.down
    remove_column :entries, :trucker_called_date
    remove_column :entries, :docs_received_date
    remove_column :entries, :isf_accepted_date
    remove_column :entries, :isf_sent_date
  end
end

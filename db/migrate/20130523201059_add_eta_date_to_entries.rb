class AddEtaDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :eta_date, :date
  end
end

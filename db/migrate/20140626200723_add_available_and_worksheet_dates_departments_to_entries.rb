class AddAvailableAndWorksheetDatesDepartmentsToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :available_date, :datetime
    add_column :entries, :worksheet_date, :datetime
    add_column :entries, :departments, :text
  end
end

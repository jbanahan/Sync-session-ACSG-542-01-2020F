class AddExceptionCreationDateToEntryExceptions < ActiveRecord::Migration
  def self.up
    add_column :entry_exceptions, :exception_creation_date, :datetime
  end

  def self.down
    remove_column :entry_exceptions, :exception_creation_date
  end
end

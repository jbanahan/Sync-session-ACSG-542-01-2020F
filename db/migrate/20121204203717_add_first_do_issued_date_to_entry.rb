class AddFirstDoIssuedDateToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :first_do_issued_date, :datetime
  end

  def self.down
    remove_column :entries, :first_do_issued_date
  end
end

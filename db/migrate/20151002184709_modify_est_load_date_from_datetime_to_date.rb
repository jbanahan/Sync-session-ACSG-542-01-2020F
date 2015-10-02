class ModifyEstLoadDateFromDatetimeToDate < ActiveRecord::Migration
  def up
    change_column :shipments, :est_load_date, :date
  end

  def down
    change_column :shipments, :est_load_date, :datetime
  end
end

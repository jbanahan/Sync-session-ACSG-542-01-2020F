class AddEstLoadDateToShipment < ActiveRecord::Migration
  def change
    add_column :shipments, :est_load_date, :datetime
  end
end

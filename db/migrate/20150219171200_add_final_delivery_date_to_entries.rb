class AddFinalDeliveryDateToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :final_delivery_date, :datetime
  end
end

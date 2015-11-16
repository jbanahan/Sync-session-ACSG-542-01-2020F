class AddEnabledBookingTypesToCompany < ActiveRecord::Migration
  def change
    add_column :companies, :enabled_booking_types, :string
  end
end

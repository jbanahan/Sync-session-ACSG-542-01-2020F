class ConvertShipmentDatesToDateTime < ActiveRecord::Migration
  def up
    change_table(:shipments, bulk: true) do |t|
      t.change :booking_received_date, :datetime
      t.change :booking_confirmed_date, :datetime
      t.change :booking_approved_date, :datetime
      t.change :booking_revised_date, :datetime
      t.change :canceled_date, :datetime
    end

    # Because there's no time component, converting the dates to datetimes will make everything existing appear
    # as midnight UTC - we really want them to be midnight Eastern so update everything and add 4 hours
    offset_seconds = ActiveSupport::TimeZone["America/New_York"].utc_offset.abs
    ['booking_received_date', 'booking_confirmed_date', 'booking_approved_date', 'booking_revised_date', 'canceled_date'].each do |date|
      execute "UPDATE shipments SET #{date} = date_add(#{date}, INTERVAL #{offset_seconds} SECOND) WHERE #{date} IS NOT NULL"
    end
  end

  def down
    change_table(:shipments, bulk: true) do |t|
      t.change :booking_received_date, :date
      t.change :booking_confirmed_date, :date
      t.change :booking_approved_date, :date
      t.change :booking_revised_date, :date
      t.change :canceled_date, :date
    end
  end
end

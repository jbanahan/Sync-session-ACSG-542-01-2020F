class CreateCalendars < ActiveRecord::Migration
  def change
    create_table :calendars do |t|
      t.string :calendar_type
      t.integer :year, :limit => 2
      t.integer :company_id

      t.timestamps
    end

    create_table :calendar_events do |t|
      t.date :event_date
      t.string :label
      t.integer :calendar_id

      t.timestamps
    end

    add_column :entries, :k84_payment_due_date, :date
  end
end

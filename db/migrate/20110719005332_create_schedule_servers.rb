class CreateScheduleServers < ActiveRecord::Migration
  def self.up
    create_table :schedule_servers do |t|
      t.string :host
      t.datetime :touch_time

    end
  end

  def self.down
    drop_table :schedule_servers
  end
end

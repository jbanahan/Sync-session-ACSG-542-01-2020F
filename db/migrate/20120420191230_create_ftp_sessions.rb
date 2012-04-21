class CreateFtpSessions < ActiveRecord::Migration
  def self.up
    create_table :ftp_sessions do |t|
      t.string :username
      t.string :server
      t.string :file_name
      t.text :log
      t.binary :data

      t.timestamps
    end
  end

  def self.down
    drop_table :ftp_sessions
  end
end

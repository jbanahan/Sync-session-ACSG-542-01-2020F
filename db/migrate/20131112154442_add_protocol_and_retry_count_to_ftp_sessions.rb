class AddProtocolAndRetryCountToFtpSessions < ActiveRecord::Migration
  def change
    add_column :ftp_sessions, :protocol, :string
    add_column :ftp_sessions, :retry_count, :integer
  end
end

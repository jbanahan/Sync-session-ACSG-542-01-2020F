class AddLastServerResponseToFtpSession < ActiveRecord::Migration
  def change
    add_column :ftp_sessions, :last_server_response, :string
  end
end

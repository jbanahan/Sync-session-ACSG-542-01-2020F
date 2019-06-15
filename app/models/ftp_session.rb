# == Schema Information
#
# Table name: ftp_sessions
#
#  created_at           :datetime         not null
#  data                 :binary
#  file_name            :string(255)
#  id                   :integer          not null, primary key
#  last_server_response :string(255)
#  log                  :text
#  protocol             :string(255)
#  retry_count          :integer
#  server               :string(255)
#  updated_at           :datetime         not null
#  username             :string(255)
#

class FtpSession < ActiveRecord::Base
  attr_accessible :data, :file_name, :last_server_response, :log, :protocol, :retry_count, :server, :username

  has_one :attachment, :as => :attachable, :dependent=>:destroy

  EMPTY_MESSAGE ||= "File was empty, not sending."

  def self.find_can_view(user)
    if user.sys_admin?
      return FtpSession.where("1=1")
    end
  end

  def can_view? user
    user.sys_admin?
  end

  def successful?
    if empty_file?
      return true
    elsif protocol == "sftp"
      # Anything other than a 0 for the code is considered an error in SFTP-land
      return !(last_server_response =~ /^0/).nil?
    else
      # The server response is supposed to start with a 3 digit response code
      # Successful responses will always be in the 200-299 range.
      return !(last_server_response =~ /^2\d\d/).nil?
    end
  end

  def empty_file?
    log.present? && log.ends_with?(EMPTY_MESSAGE)
  end

  def self.purge reference_date
    FtpSession.where("created_at < ?", reference_date).find_each do |session|
      session.destroy
    end
  end
end

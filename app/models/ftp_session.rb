class FtpSession < ActiveRecord::Base
  has_one :attachment, :as => :attachable, :dependent=>:destroy

  def self.find_can_view(user)
    if user.sys_admin?
      return FtpSession.where("1=1")
    end
  end

  def can_view? user
    user.sys_admin?
  end

  def successful?
    if protocol == "sftp"
      # Anything other than a 0 for the code is considered an error in SFTP-land
      return !(last_server_response =~ /^0/).nil?
    else
      # The server response is supposed to start with a 3 digit response code
      # Successful responses will always be in the 200-299 range.
      return !(last_server_response =~ /^2\d\d/).nil?
    end
  end
end

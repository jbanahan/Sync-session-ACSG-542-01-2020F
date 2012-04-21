class FtpSession < ActiveRecord::Base
  def self.find_can_view(user)
    if user.sys_admin?
      return FtpSession.where("1=1")
    end
  end
end

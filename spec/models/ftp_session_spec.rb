require 'spec_helper'

describe FtpSession do

  context :successful? do
    it "should report ftp codes starting with 2 followed by other digits as successful" do
      f = FtpSession.new
      [200..299].each do |i|
        f.status_code = "#{i} This is a test."
        f.successful?.should be_true
      end
    end

    it "should report all non 2xx codes as unsuccesful" do
      f = FtpSession.new
      f.successful?.should be_false
      f.status_code = ""
      f.successful?.should be_false
      f.status_code = "400 Error"
      f.successful?.should be_false
      f.status_code = "500 Error"
      f.successful?.should be_false
      f.status_code = "2 Error"
      f.successful?.should be_false
      f.status_code = "20 Error"
      f.successful?.should be_false
    end
  end

  context :can_view? do
    it "should allow sys_admin users to view" do
      user = User.new
      user.sys_admin = true
      f = FtpSession.new
      f.can_view?(user).should be_true
      user.sys_admin = false
      f.can_view?(user).should be_false
    end
  end
end
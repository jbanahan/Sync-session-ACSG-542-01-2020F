require 'spec_helper'

describe FtpSession do

  context "successful?" do
    before :each do 
      @f = FtpSession.new
    end

    context "ftp" do 
      before :each do
        @f.protocol = "ftp"
      end

      it "should report ftp codes starting with 2 followed by other digits as successful" do
        [200..299].each do |i|
          @f.last_server_response = "#{i} This is a test."
          expect(@f.successful?).to be_truthy
        end
      end

      it "should report all non 2xx codes as unsuccesful" do
        expect(@f.successful?).to be_falsey
        @f.last_server_response = ""
        expect(@f.successful?).to be_falsey
        @f.last_server_response = "400 Error"
        expect(@f.successful?).to be_falsey
        @f.last_server_response = "500 Error"
        expect(@f.successful?).to be_falsey
        @f.last_server_response = "2 Error"
        expect(@f.successful?).to be_falsey
        @f.last_server_response = "20 Error"
        expect(@f.successful?).to be_falsey
      end
    end
    

    context "sftp" do
      before :each do
        @f.protocol = "sftp"
      end

      it "should report status codes starting with 0 as successful, all others as failed" do
        @f.last_server_response = ""
        expect(@f.successful?).to be_falsey
        @f.last_server_response = "0 Yeah!"
        expect(@f.successful?).to be_truthy
        (1..31).each do |x|
          @f.last_server_response = "#{x} Boo!"
          expect(@f.successful?).to be_falsey
        end
      end
    end
  end

  context "can_view?" do
    it "should allow sys_admin users to view" do
      user = User.new
      user.sys_admin = true
      f = FtpSession.new
      expect(f.can_view?(user)).to be_truthy
      user.sys_admin = false
      expect(f.can_view?(user)).to be_falsey
    end
  end
end
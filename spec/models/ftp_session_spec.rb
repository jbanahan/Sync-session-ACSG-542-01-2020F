require 'spec_helper'

describe FtpSession do

  context "successful?" do
    subject { FtpSession.new log: "" }

    context "ftp" do 
      before :each do
        subject.protocol = "ftp"
      end

      it "should report ftp codes starting with 2 followed by other digits as successful" do
        [200..299].each do |i|
          subject.last_server_response = "#{i} This is a test."
          expect(subject.successful?).to be_truthy
        end
      end

      it "should report all non 2xx codes as unsuccesful" do
        expect(subject.successful?).to be_falsey
        subject.last_server_response = ""
        expect(subject.successful?).to be_falsey
        subject.last_server_response = "400 Error"
        expect(subject.successful?).to be_falsey
        subject.last_server_response = "500 Error"
        expect(subject.successful?).to be_falsey
        subject.last_server_response = "2 Error"
        expect(subject.successful?).to be_falsey
        subject.last_server_response = "20 Error"
        expect(subject.successful?).to be_falsey
      end
    end
    

    context "sftp" do
      before :each do
        subject.protocol = "sftp"
      end

      it "should report status codes starting with 0 as successful, all others as failed" do
        subject.last_server_response = ""
        expect(subject.successful?).to be_falsey
        subject.last_server_response = "0 Yeah!"
        expect(subject.successful?).to be_truthy
        (1..31).each do |x|
          subject.last_server_response = "#{x} Boo!"
          expect(subject.successful?).to be_falsey
        end
      end
    end

    it "recognizes empty file sends as successful" do
      subject.log = "Some Info\nFile was empty, not sending."
      expect(subject.successful?).to eq true
    end
  end

  context "can_view?" do
    it "should allow sys_admin users to view" do
      user = User.new
      user.sys_admin = true
      expect(subject.can_view?(user)).to be_truthy
      user.sys_admin = false
      expect(subject.can_view?(user)).to be_falsey
    end
  end
end
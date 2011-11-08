require 'spec_helper'

describe OpenMailer do
  describe 'send_s3_file' do
    before :each do
      @user = Factory(:user)
      @to = 'a@b.com'
      @cc = 'cc@cc.com'
      @subject = 'my subject'
      @body = 'my body'
      @filename = 'a.xls'
      @bucket = 'mybucket'
      @s3_path = "my/path/#{@filename}"
      @s3_content = 'some content here'
      
      #mock s3 handling
      OpenChain::S3.should_receive(:get_data).with(@bucket,@s3_path).and_return(@s3_content)
    end
    it 'should attach file from s3' do
      OpenMailer.send_s3_file(@user, @to, @cc, @subject, @body, @bucket, @s3_path).deliver
      
      mail = ActionMailer::Base.deliveries.pop
      mail.to.should == [@to]
      mail.cc.should == [@cc]
      mail.subject.should == @subject
      mail.has_attachments?.should == true
      mail.attachments.first.filename.should == @filename
    end
    it 'should take attachment_name parameter' do
      alt_name = 'x.y'
      OpenMailer.send_s3_file(@user, @to, @cc, @subject, @body, @bucket, @s3_path,alt_name).deliver
      mail = ActionMailer::Base.deliveries.pop
      mail.attachments.first.filename.should == alt_name
    end
  end
end

require 'spec_helper'

describe OpenMailer do
  context "support tickets" do
    before :each do
      @requestor = Factory(:user)
      @st = SupportTicket.new(:requestor=>@requestor,:subject=>"SUB",:body=>"BOD")
    end
    describe 'send_support_ticket_to_agent' do
      it "should send ticket to agent when agent is set" do
        agent = Factory(:user)
        @st.agent = agent
        OpenMailer.send_support_ticket_to_agent(@st).deliver!
        mail = ActionMailer::Base.deliveries.pop
        mail.to.should == [ agent.email ]
        mail.subject.should == "[Support Ticket Update]: #{@st.subject}"
        mail.body.raw_source.should include @st.body
      end
      it "should send ticket to generic mailbox when agent is not set" do
        OpenMailer.send_support_ticket_to_agent(@st).deliver!
        mail = ActionMailer::Base.deliveries.pop
        mail.to.should == [ "support@vandegriftinc.com" ]
        mail.subject.should == "[Support Ticket Update]: #{@st.subject}"
        mail.body.raw_source.should include @st.body
      end
    end
    describe 'send_support_ticket_to_requestor' do
      it "should send ticket to requestor" do
        OpenMailer.send_support_ticket_to_requestor(@st).deliver!

        mail = ActionMailer::Base.deliveries.pop
        mail.to.should == [ @requestor.email ]
        mail.subject.should == "[Support Ticket Update]: #{@st.subject}"
        mail.body.raw_source.should include @st.body
      end
    end
  end
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
      mail.postmark_attachments.should have(1).item
      pa = mail.postmark_attachments.first
      pa["Name"].should == @filename
      pa["Content"].should == Base64.encode64(@s3_content)
      pa["ContentType"].should == "application/octet-stream"
    end
    it 'should take attachment_name parameter' do
      alt_name = 'x.y'
      OpenMailer.send_s3_file(@user, @to, @cc, @subject, @body, @bucket, @s3_path,alt_name).deliver
      mail = ActionMailer::Base.deliveries.pop
      mail.postmark_attachments.should have(1).item
      pa = mail.postmark_attachments.first
      pa["Name"].should == alt_name
    end
  end
end

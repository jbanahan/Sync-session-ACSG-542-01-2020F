require 'spec_helper'

describe OpenMailer do
  context "simple text" do
    it "should send message" do
      OpenMailer.send_simple_text("test@vfitrack.net", "my subject", "my body\ngoes here").deliver!
      mail = ActionMailer::Base.deliveries.pop
      mail.to.should == ['test@vfitrack.net']
      mail.subject.should == 'my subject'
      mail.body.raw_source.strip.should == "my body\ngoes here"
    end
  end
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

  context :send_simple_html do 
    it "should send html email with an attachment" do
      Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"

        OpenMailer.send_simple_html("me@there.com", "Subject", "<p>Body</p>", f).deliver

        mail = ActionMailer::Base.deliveries.pop
        mail.to.should == ["me@there.com"]
        mail.subject.should == "Subject"
        mail.body.raw_source.should match("&lt;p&gt;Body&lt;/p&gt;")
        mail.postmark_attachments.should have(1).item
        pa = mail.postmark_attachments.first
        pa["Name"].should == File.basename(f)
        pa["Content"].should == Base64.encode64(File.read(f))
        pa["ContentType"].should == "application/octet-stream"
      end
    end

    it "should send html email with multiple attachments" do
      Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"

        Tempfile.open(["file2", "txt"]) do |f2|
          f2.binmode
          f << "Content2"
          
          OpenMailer.send_simple_html("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2]).deliver

          mail = ActionMailer::Base.deliveries.pop
          mail.to.should == ["me@there.com"]
          mail.subject.should == "Subject"
          mail.body.raw_source.should match("<p>Body</p>")
          mail.postmark_attachments.should have(2).item

          pa = mail.postmark_attachments.first
          pa["Name"].should == File.basename(f)
          pa["Content"].should == Base64.encode64(File.read(f))
          pa["ContentType"].should == "application/octet-stream"

          pa = mail.postmark_attachments.second
          pa["Name"].should == File.basename(f2)
          pa["Content"].should == Base64.encode64(File.read(f2))
          pa["ContentType"].should == "application/octet-stream"
        end
      end
    end

    it "should save an email attachment if the attachment is too large" do
      MasterSetup.get.update_attributes(:request_host=>"host.xxx")

      # One attachment should get mailed, the second should get saved off and a link for
      # downloading added to the email
      Tempfile.open(["file", "txt"]) do |f|
        Tempfile.open(["file2", "txt"]) do |f2|
          f.binmode
          f << "Content"
          f2.binmode
          f << "Content2"

          OpenMailer.any_instance.should_receive(:large_attachment?).with(f).and_return true
          OpenMailer.any_instance.should_receive(:large_attachment?).with(f2).and_return false

          OpenMailer.send_simple_html("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2]).deliver

          mail = ActionMailer::Base.deliveries.pop
          mail.postmark_attachments.should have(1).item

          pa = mail.postmark_attachments.first
          pa["Name"].should == File.basename(f2)
          pa["Content"].should == Base64.encode64(File.read(f2))
          pa["ContentType"].should == "application/octet-stream"

          ea = EmailAttachment.all.first
          ea.should_not be_nil
          ea.attachment.attached_file_name.should == File.basename(f)

          body = <<EMAIL
An attachment named '#{File.basename(f)}' for this message was larger than the maximum system size.
Click <a href='http://host.xxx/email_attachments/#{ea.id}'>here</a> to download the attachment directly.
All system attachments are deleted after seven days, please retrieve your attachments promptly.
EMAIL
          mail.body.raw_source.should match(body)
        end
      end    
    end

    it "should utilize original_filename method for file attachments" do
      Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"
        Attachment.add_original_filename_method f
        f.original_filename = "test.txt"

        OpenMailer.send_simple_html("me@there.com", "Subject", "<p>Body</p>", f).deliver

        mail = ActionMailer::Base.deliveries.pop
        pa = mail.postmark_attachments.first
        pa["Name"].should == "test.txt"
        pa["Content"].should == Base64.encode64(File.read(f))
        pa["ContentType"].should == "application/octet-stream"
      end
    end
  end

  context :send_generic_exception do
    it "should send an exception email" do
      # This is just primarily a test to make sure regressions weren't introduced
      # when the save_large_attachment method was modified
      MasterSetup.get.update_attributes(:request_host=>"host.xxx")

      Tempfile.open(["file", "txt"]) do |f|
        e = nil
        begin
          raise "Error"
        rescue
          e = $!
        end
        f.binmode
        f << "Test"

        OpenMailer.any_instance.should_receive(:large_attachment?).with(f.path).and_return true

        OpenMailer.send_generic_exception(e, ["Test", "Test2"], "Error Message", nil, [f.path]).deliver

        mail = ActionMailer::Base.deliveries.pop
        pa = mail.postmark_attachments.length.should == 0

        ea = EmailAttachment.all.first
        ea.should_not be_nil
        ea.attachment.attached_file_name.should == File.basename(f)

        body = <<EMAIL
An attachment named '#{File.basename(f)}' for this message was larger than the maximum system size.
Click <a href='http://host.xxx/email_attachments/#{ea.id}'>here</a> to download the attachment directly.
All system attachments are deleted after seven days, please retrieve your attachments promptly.
EMAIL
        mail.body.raw_source.should match(body)
      end
    end

    it "should truncate message subject at 2000 chars" do
      message_subject = "This is a subject."
      message_subject += message_subject while message_subject.length < 200
      e = (raise "Error" rescue $!)
      m = OpenMailer.send_generic_exception(e, ["Test", "Test2"], message_subject)
      m.subject.should eq ("[chain.io Exception] - #{message_subject}")[0..99]
    end
  end

  context :send_invite do
    before :each do
      MasterSetup.get.update_attributes request_host: "localhost"
      @user = Factory(:user, first_name: "Joe", last_name: "Schmoe", email: "me@there.com")
    end

    it "should send an invite email" do
      pwd = "password"
      mail = OpenMailer.send_invite @user, pwd
      mail.subject.should eq "[chain.io] Welcome, Joe Schmoe!"
      mail.to.should eq [@user.email]

      mail.body.raw_source.should match /Username: #{@user.username}/
      mail.body.raw_source.should match /Temporary Password: #{pwd}/
      mail.body.raw_source.should match /#{url_for(host: MasterSetup.get.request_host, controller: 'user_sessions', action: 'new', protocol: 'https')}/
    end
  end
end

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

      @tempfile = Tempfile.new ["s3_content", ".txt"]
      @tempfile.binmode
      @tempfile << @s3_content
      @tempfile.rewind
      
      #mock s3 handling
      OpenChain::S3.should_receive(:download_to_tempfile).with(@bucket,@s3_path).and_return(@tempfile)
    end
    after :each do
      @tempfile.close!
    end
    it 'should attach file from s3' do
      OpenMailer.send_s3_file(@user, @to, @cc, @subject, @body, @bucket, @s3_path).deliver
      
      mail = ActionMailer::Base.deliveries.pop
      mail.to.should == [@to]
      mail.cc.should == [@cc]
      mail.subject.should == @subject
      mail.attachments[@filename].should_not be_nil
      pa = mail.attachments[@filename]
      pa.content_type.should == "application/octet-stream; charset=UTF-8"
      pa.read.should == @s3_content
      
    end
    it 'should take attachment_name parameter' do
      alt_name = 'x.y'
      OpenMailer.send_s3_file(@user, @to, @cc, @subject, @body, @bucket, @s3_path,alt_name).deliver
      mail = ActionMailer::Base.deliveries.pop
      mail.attachments[alt_name].should_not be_nil
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

        pa = mail.attachments[File.basename(f)]
        pa.should_not be_nil
        pa.read.should == File.read(f)
        pa.content_type.should == "application/octet-stream"
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
          mail.attachments.should have(2).items

          pa = mail.attachments[File.basename(f)]
          pa.should_not be_nil
          pa.read.should == File.read(f)
          pa.content_type.should == "application/octet-stream"

          pa = mail.attachments[File.basename(f2)]
          pa.should_not be_nil
          pa.read.should == File.read(f2)
          pa.content_type.should == "application/octet-stream"
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
          mail.attachments.should have(1).item

          pa = mail.attachments[File.basename(f2)]
          pa.should_not be_nil
          pa.read.should == File.read(f2)
          pa.content_type.should == "application/octet-stream"

          ea = EmailAttachment.all.first
          ea.should_not be_nil
          ea.attachment.attached_file_name.should == File.basename(f)

          body = <<EMAIL
An attachment named '#{File.basename(f)}' for this message was larger than the maximum system size.
Click <a href='#{OpenMailer::LINK_PROTOCOL}://host.xxx/email_attachments/#{ea.id}'>here</a> to download the attachment directly.
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
        pa = mail.attachments['test.txt']
        pa.should_not be_nil
        pa.read.should == File.read(f)
        pa.content_type.should == "application/octet-stream"
      end
    end
  end

  context :send_generic_exception do
    it "should send an exception email" do
      error = StandardError.new "Test"
      error.set_backtrace ["Backtrace", "Line 1", "Line 2"]

      Tempfile.open(["file", "txt"]) do |f|
        f << "Test File"
        f.flush
        f.rewind

        OpenMailer.send_generic_exception(error, ["My Message"], nil, nil, [f.path]).deliver

        mail = ActionMailer::Base.deliveries.pop
        source = mail.body.raw_source
        source.should include("Error: #{error}")
        source.should include("Message: #{error.message}")
        source.should include("Master UUID: #{MasterSetup.get.uuid}")
        source.should include("Root: #{Rails.root.to_s}")
        source.should include("Host: #{Socket.gethostname}")
        source.should include("Process ID: #{Process.pid}")
        source.should include("Additional Messages:")
        source.should include("My Message")
        source.should include("Backtrace:")
        source.should include(error.backtrace.join("\n"))

        mail.attachments[File.basename(f.path)].read.should eq "Test File"
      end
    end

    it "should send an exception email using argument overrides" do
      # error message and backtrace should come from the method arguments and not the exception itself
      error = StandardError.new "Test"
      error.set_backtrace ["Backtrace", "Line 1", "Line 2"]

      OpenMailer.send_generic_exception(error, ["My Message"], "Override Message", ["Fake", "Backtrace"]).deliver

      mail = ActionMailer::Base.deliveries.pop
      source = mail.body.raw_source
      source.should_not include(error.backtrace.join("\n"))
      source.should_not include("Message: #{error.message}")
      source.should include("Fake\nBacktrace")
      source.should include("Message: Override Message")
    end

    it "should send an exception email with a large attachment warning" do
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
        pa = mail.attachments.size.should == 0

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
      m.subject.should eq ("[VFI Track Exception] - #{message_subject}")[0..99]
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
      mail.subject.should eq "[VFI Track] Welcome, Joe Schmoe!"
      mail.to.should eq [@user.email]

      mail.body.raw_source.should match /Username: #{@user.username}/
      mail.body.raw_source.should match /Temporary Password: #{pwd}/
      mail.body.raw_source.should match /#{url_for(host: MasterSetup.get.request_host, controller: 'user_sessions', action: 'new', protocol: OpenMailer::LINK_PROTOCOL)}/
    end
  end

  context :send_uploaded_items do
    before :each do
      @user = Factory(:user, first_name: "Joe", last_name: "Schmoe", email: "me@there.com")
    end

    it "should send imported file data" do
      data = "This is my data, there are many like it but this one is mine."
      imported_file = double("ImportedFile")
      imported_file.stub(:attached_file_name).and_return "test.txt"
      imported_file.stub(:module_type).and_return "Product"

      m = OpenMailer.send_uploaded_items "you@there.com", imported_file, data, @user
      m.to.should eq ["you@there.com"]
      m.reply_to.should eq [@user.email]
      m.subject.should eq "[VFI Track] Product File Result"

      m.attachments["test.txt"].should_not be_nil
      m.attachments["test.txt"].read.should eq data
    end

    it "should not add attachment if data is too large" do
      data = "This is my data, there are many like it but this one is mine."
      imported_file = double("ImportedFile")
      imported_file.stub(:attached_file_name).and_return "test.txt"
      imported_file.stub(:module_type).and_return "Product"

      OpenMailer.any_instance.should_receive(:save_large_attachment).and_return true

      m = OpenMailer.send_uploaded_items "you@there.com", imported_file, data, @user
      m.attachments["test.txt"].should be_nil
    end
  end
  describe :send_survey_invite do
    context 'with a non-blank subtitle' do
      before :each do
        @user = Factory(:user, first_name: "Joe", last_name: "Schmoe", email: "me@there.com")
        @survey = Factory(:survey)
        @survey.email_subject = "test subject"
        @survey.email_body = "test body"

        survey_response = @survey.survey_responses.build :user => @user, :subtitle => 'test subtitle'

        @m = OpenMailer.send_survey_invite(survey_response)
      end

      it 'appends a line including the label to the body of the email and the subject' do
        expect(@m.subject).to eq "test subject - test subtitle"
        expect(@m.body.raw_source).to match(/To view the survey labeled &#x27;test subtitle,&#x27; follow this link:/)
      end
    end

    context 'without a blank subtitle' do
      before :each do
        @user = Factory(:user, first_name: "Joe", last_name: "Schmoe", email: "me@there.com")
        @survey = Factory(:survey)
        @survey.email_subject = "test subject"
        @survey.email_body = "test body"
        survey_response = @survey.survey_responses.build :user => @user

        @m = OpenMailer.send_survey_invite(survey_response)
      end

      it 'does not add a blank subtitle line to the normal body or subject' do
        expect(@m.subject).to eq "test subject"
        expect(@m.body.raw_source).to match(/To view the survey, follow this link:/)
      end
    end
  end
end

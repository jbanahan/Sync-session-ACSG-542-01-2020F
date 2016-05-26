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
  describe "send_ack_file_exception" do
    it "should attach file for ack file exceptions" do
      @tempfile = Tempfile.new ["s3_content", ".txt"]
      @tempfile.binmode
      @tempfile << "Content of a tempfile"
      @tempfile.rewind

      OpenMailer.send_ack_file_exception("example@example.com",["Error 1","Error 2","Error 3"], @tempfile, "s3_content.txt","Sync code").deliver!
      m = OpenMailer.deliveries.pop
      m.to.first.should == "example@example.com"
      m.subject.should == "[VFI Track] Ack File Processing Error"
      m.attachments.should have(1).item

      @tempfile.close!
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
    it "should attach file from s3" do
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
    it "should take attachment_name parameter" do
      alt_name = 'x.y'
      OpenMailer.send_s3_file(@user, @to, @cc, @subject, @body, @bucket, @s3_path,alt_name).deliver
      mail = ActionMailer::Base.deliveries.pop
      mail.attachments[alt_name].should_not be_nil
    end
  end

  describe :send_registration_request do
    it "should send email with registration details to support address" do
      fields = { email: "john_doe@acme.com", fname: "John", lname: "Doe", company: "Acme", 
                  cust_no: "123456789", contact: "Jane Smith", system_code: "HAL9000"}

      OpenMailer.send_registration_request(fields).deliver!
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["support@vandegriftinc.com"]
      expect(mail.subject).to eq "Registration Request"
      ["Email: #{fields[:email]}", "First Name: #{fields[:fname]}", "Last Name: #{fields[:lname]}", "Company: #{fields[:company]}", "Customer Number: #{fields[:cust_no]}",
       "Contact: #{fields[:contact]}", "System Code: #{fields[:system_code]}"].each {|f| expect(mail.body).to include f }
    end
  end

  context :send_simple_html do 
    describe "in development environment" do
      it "should send an email to User 1's email" do
        # For some reason, the test seems to fail when run from spork on an undefined message variable in the layout.
        # It runs fine via the rspec commandline, not sure what's going on.

        Rails.stub(:env).and_return ActiveSupport::StringInquirer.new("development")
        
        #Ensure there's a user set up, it seems sometimes there's not in circle environment
        user = Factory(:user, email: "me@there.com")
        
        OpenMailer.send_simple_html("example@example.com", "Test subject","<p>Test body</p>").deliver!

        m = OpenMailer.deliveries.last
        m.to.first.should == User.first.email
        expect(OpenMailer.deliveries.last.header['X-ORIGINAL-TO'].value).to eq 'example@example.com'
      end

      it "allows sending additional mail options" do
        # Just check that the cc option is utilized when passed.  The options hash just gets passed directly
        # to the #mail method.
        OpenMailer.send_simple_html("example@example.com", "Test subject","<p>Test body</p>", nil, cc: "test@test.com").deliver!

        m = OpenMailer.deliveries.last
        expect(m.cc).to eq ["test@test.com"]
      end

      it "should handle multiple addresses in to field" do
        Rails.stub(:env).and_return ActiveSupport::StringInquirer.new("development")
        
        #Ensure there's a user set up, it seems sometimes there's not in circle environment
        user = Factory(:user, email: "me@there.com")
        
        OpenMailer.send_simple_html("example@example.com, you@there.com", "Test subject","<p>Test body</p>").deliver!

        m = OpenMailer.deliveries.last
        m.to.first.should == User.first.email
        expect(OpenMailer.deliveries.last.header['X-ORIGINAL-TO'].value).to eq 'example@example.com, you@there.com'
      end

      it "explodes groups into component email addresses" do
        group = Factory(:group, system_code: "GROUP")
        user1 = Factory(:user, email: "me@there.com")
        user2 = Factory(:user, email: "you@there.com")

        group.users << user1
        group.users << user2

        OpenMailer.send_simple_html(group, "Subject","").deliver!

        m = OpenMailer.deliveries.last
        expect(m.to.first).to eq user1.email
        expect(m.to.second).to eq user2.email
      end
    end

    it "should send html email with an attachment" do
      Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"

        OpenMailer.any_instance.should_receive(:blank_attachment?).and_return false
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
          f2 << "Content2"
          f2.flush
          f.flush
          
          OpenMailer.send_simple_html("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2]).deliver

          mail = ActionMailer::Base.deliveries.pop
          mail.to.should == ["me@there.com"]
          mail.subject.should == "Subject"
          mail.body.raw_source.should match("<p>Body</p>")
          mail.attachments.should have(2).items

          pa = mail.attachments[File.basename(f)]
          pa.should_not be_nil
          pa.read.should == File.read(f)
          pa.content_type.should == "application/octet-stream; charset=UTF-8"

          pa = mail.attachments[File.basename(f2)]
          pa.should_not be_nil
          pa.read.should == File.read(f2)
          pa.content_type.should == "application/octet-stream; charset=UTF-8"
        end
      end
    end

    it "should not save an email attachment if the attachment is empty" do
      MasterSetup.get.update_attributes(:request_host=>"host.xxx")
      Tempfile.open(["file","txt"]) do |f|
        Tempfile.open(["file2", "txt"]) do |f2|
          f.binmode
          f << "Content"
          f2.binmode
          f2 << "Content2"
          f2.flush

          OpenMailer.any_instance.should_receive(:blank_attachment?).with(f).and_return true
          OpenMailer.any_instance.should_receive(:blank_attachment?).with(f2)

          OpenMailer.send_simple_html("me@there.com","Subject","<p>Body</p>".html_safe,[f,f2]).deliver!

          mail = ActionMailer::Base.deliveries.pop
          mail.attachments.should have(1).item

          pa = mail.attachments[File.basename(f2)]
          pa.should_not be_nil
          pa.read.should == File.read(f2)
          expect(pa.content_type).to match /application\/octet-stream/
          
          ea = EmailAttachment.all.first
          ea.should be_nil
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
          f2 << "Content2"

          #This chain means f is too large, but f2 is neither too large nor blank. Thus we should have 1 attachment.
          OpenMailer.any_instance.should_receive(:large_attachment?).with(f).and_return true
          OpenMailer.any_instance.should_receive(:large_attachment?).with(f2).and_return false
          OpenMailer.any_instance.should_receive(:blank_attachment?).and_return false

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

        OpenMailer.any_instance.should_receive(:blank_attachment?).and_return false
        OpenMailer.send_simple_html("me@there.com", "Subject", "<p>Body</p>", f).deliver

        mail = ActionMailer::Base.deliveries.pop
        pa = mail.attachments['test.txt']
        pa.should_not be_nil
        pa.read.should == File.read(f)
        pa.content_type.should == "application/octet-stream"
      end
    end
  end

  context :auto_send_attachments do 
    it "should send html email with an attachment" do
      Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"

        OpenMailer.any_instance.should_receive(:blank_attachment?).and_return false
        OpenMailer.auto_send_attachments("me@there.com", "Subject", "<p>Body\n</p>", f, "Test name", "test@email.com").deliver

        mail = ActionMailer::Base.deliveries.pop
        mail.to.should == ["me@there.com"]
        mail.reply_to.should == ["test@email.com"]
        mail.subject.should == "Subject"
        mail.body.raw_source.should match("&lt;p&gt;Body<br>&lt;/p&gt;")                                            

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
          f2 << "Content2"
          f2.flush
          f.flush
          
          OpenMailer.auto_send_attachments("me@there.com", "Subject", "<p>Body\n</p>", [f, f2], "Test name", "test@email.com").deliver

          mail = ActionMailer::Base.deliveries.pop
          mail.to.should == ["me@there.com"]
          mail.reply_to.should == ["test@email.com"]
          mail.subject.should == "Subject"
          mail.body.raw_source.should match("&lt;p&gt;Body<br>&lt;/p&gt;")
          mail.attachments.should have(2).items

          pa = mail.attachments[File.basename(f)]
          pa.should_not be_nil
          pa.read.should == File.read(f)
          pa.content_type.should == "application/octet-stream; charset=UTF-8"

          pa = mail.attachments[File.basename(f2)]
          pa.should_not be_nil
          pa.read.should == File.read(f2)
          pa.content_type.should == "application/octet-stream; charset=UTF-8"
        end
      end
    end

    it "should not save an email attachment if the attachment is empty" do
      MasterSetup.get.update_attributes(:request_host=>"host.xxx")
      Tempfile.open(["file","txt"]) do |f|
        Tempfile.open(["file2", "txt"]) do |f2|
          f.binmode
          f << "Content"
          f2.binmode
          f2 << "Content2"
          f2.flush

          OpenMailer.any_instance.should_receive(:blank_attachment?).with(f).and_return true
          OpenMailer.any_instance.should_receive(:blank_attachment?).with(f2)

          OpenMailer.auto_send_attachments("me@there.com","Subject","<p>Body</p>".html_safe,[f,f2], "Test name", "test@email.com").deliver!

          mail = ActionMailer::Base.deliveries.pop
          mail.attachments.should have(1).item

          pa = mail.attachments[File.basename(f2)]
          pa.should_not be_nil
          pa.read.should == File.read(f2)
          expect(pa.content_type).to match /application\/octet-stream/

          ea = EmailAttachment.all.first
          ea.should be_nil
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
          f2 << "Content2"

          #This chain means f is too large, but f2 is neither too large nor blank. Thus we should have 1 attachment.
          OpenMailer.any_instance.should_receive(:large_attachment?).with(f).and_return true
          OpenMailer.any_instance.should_receive(:large_attachment?).with(f2).and_return false
          OpenMailer.any_instance.should_receive(:blank_attachment?).and_return false

          OpenMailer.auto_send_attachments("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2], "Test name", "test@email.com").deliver

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

        OpenMailer.any_instance.should_receive(:blank_attachment?).and_return false
        OpenMailer.auto_send_attachments("me@there.com", "Subject", "<p>Body</p>", f, "Test name", "test@email.com").deliver

        mail = ActionMailer::Base.deliveries.pop
        pa = mail.attachments['test.txt']
        pa.should_not be_nil
        pa.read.should == File.read(f)
        pa.content_type.should == "application/octet-stream"
      end
    end

    it "should include the full name and email of the attachment sender" do
      Tempfile.open(["file","txt"]) do |f|
        OpenMailer.any_instance.should_receive(:blank_attachment?).and_return false
        OpenMailer.auto_send_attachments("me@there.com", "Subject","<p>Body</p>", f, "Test name", "test@email.com").deliver

        mail = ActionMailer::Base.deliveries.pop
        mail.body.should match(/by Test name \(test\@email\.com\)/)
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

  describe :send_high_priority_tasks do

    before :each do
      @u1 = Factory(:user, email: "me@there.com")
      @pd1 = Factory(:project_deliverable, assigned_to: @u1, description: "PD1 Description")
      OpenMailer.send_high_priority_tasks(@u1, [@pd1]).deliver!
    end

    it "should be sent to the correct user" do
      OpenMailer.deliveries.pop.to.first.should == "me@there.com"
    end

    it "should have a subject line of the correct form" do
      OpenMailer.deliveries.pop.subject.should match(/\[VFI Track\] Task Priorities \- \d{2}\/\d{2}\/\d{2}/)
    end

    it "should have the project deliverable descriptions in the body" do
      OpenMailer.deliveries.pop.body.should match(/PD1 Description/)
    end

  end

  describe :send_survey_invite do
    before :each do
      @user = Factory(:user, first_name: "Joe", last_name: "Schmoe", email: "me@there.com")
      @survey = Factory(:survey)
      @survey.email_subject = "test subject"
      @survey.email_body = "test body"
      @survey_response = @survey.survey_responses.build :user => @user
    end
    
    context 'with a non-blank subtitle' do
      it "appends a line including the label to the body of the email and the subject" do
        @survey_response.update_attributes! subtitle: "test subtitle"
        m = OpenMailer.send_survey_invite(@survey_response)
        expect(m.body.raw_source).to match(/To view the survey labeled &#x27;test subtitle,&#x27; follow this link:/)
      end
    end

    context 'with a blank subtitle' do
      it "does not add a blank subtitle line to the normal body or subject" do
        m = OpenMailer.send_survey_invite(@survey_response)
        expect(m.subject).to eq "test subject"
        expect(m.body.raw_source).to match(/To view the survey, follow this link:/)
      end
    end

    context 'with user group' do
      before :each do
        @group = Factory(:group)
        @user1 = Factory(:user)
        @user2 = Factory(:user)
        @user1.groups << @group
        @user2.groups << @group
        @survey_response.group = @group
      end

      it "splits out user groups emails" do
        OpenMailer.send_survey_invite(@survey_response).deliver!
        m = ActionMailer::Base.deliveries.pop
        expect(m.to).to include @user.email
        expect(m.to).to include @user1.email
        expect(m.to).to include @user2.email

        expect(m.header["X-ORIGINAL-GROUP-TO"].value).to eq @group.system_code
      end
    end
  end

  describe :send_survey_reminder do
  
    it "sends email with specified recipients, subject & body, with a link to the survey" do
      sr = Factory(:survey_response)
      ms = double()
      ms.should_receive(:request_host).and_return "localhost:3000"
      MasterSetup.stub(:get).and_return ms
      link_addr = "http://localhost:3000/survey_responses/#{sr.id}"

      email_to = ["john.smith@abc.com", "sue.anderson@cbs.com"]
      email_subject = "don't forget to complete your survey"
      email_body = "behold, a survey you almost forgot to complete!"
      link_addr = "http://localhost:3000/survey_responses/#{sr.id}"

      OpenMailer.send_survey_reminder(sr, email_to, email_subject, email_body).deliver!
      m = ActionMailer::Base.deliveries.pop

      expect(m.to).to eq email_to
      expect(m.subject).to eq email_subject
      expect(m.body.raw_source).to match(/#{Regexp.quote(email_body)}.+#{Regexp.quote(link_addr)}/)
    end

  end

  describe :send_search_result_manually do
    before(:each) { @u = Factory(:user, email: "me@here.com")}

    it "sends email with to, reply_to, subject, body, and attachment" do
       Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"

        OpenMailer.any_instance.should_receive(:blank_attachment?).and_return false
        OpenMailer.send_search_result_manually("you@there.com", "Subject", "<p>Body</p>", f.path, @u).deliver!

        mail = ActionMailer::Base.deliveries.pop
        mail.to.should == ["you@there.com"]
        mail.reply_to.should == ["me@here.com"]
        mail.subject.should == "Subject"
        mail.body.raw_source.should match("&lt;p&gt;Body&lt;/p&gt;")

        pa = mail.attachments[File.basename(f)]
        pa.should_not be_nil
        pa.read.should == File.read(f)
        pa.content_type.should == "application/octet-stream"
      end

    end

  end

  describe :log_email, email_log: true do

    it "saves outgoing e-mail fields and attachments" do   
      sub = "what it's about"
      to = "john@doe.com; me@there.com, you@here.com"
      body = "Lorem ipsum dolor sit amet, consectetur adipisicing elit."
      OpenMailer.any_instance.stub(:blank_attachment?).and_return false

      Tempfile.open(['tempfile_a', '.txt']) do |file1|
        Tempfile.open(['tempfile_b', '.txt']) do |file2|
          OpenMailer.send_simple_html to, sub, body, [file1, file2]
          email = SentEmail.last
          
          expect(email.email_subject).to eq sub
          expect(email.email_to).to eq "john@doe.com, me@there.com, you@here.com"
          expect(email.email_body).to include "Lorem ipsum dolor sit amet, consectetur adipisicing elit."
          # Make sure we're logging all the html too on html messages
          expect(email.email_body).to include '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">'
          expect(File.basename(email.attachments.first.attached_file_name, '.*')).to include 'tempfile_a'
          expect(File.basename(email.attachments.last.attached_file_name, '.*')).to include 'tempfile_b'
        end
      end
    end

    it "saves body data from html mails without attachments" do
      # Under the hood, the email body is done differently if there's no file attachments...so make sure the logging works 
      # fine when the message doesn't have any attachments (.ie it's not a multi-part email)
      OpenMailer.send_simple_html "me@there.com", "Subject", "This is a test"
      email = SentEmail.where(email_subject: "Subject").first
      expect(email.email_body).to include "This is a test"
      expect(email.email_body).to include '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">'
    end

    it "saves data from text emails" do
      OpenMailer.send_simple_text "me@there.com", "Subject", "This is a test"
      email = SentEmail.where(email_subject: "Subject").first
      expect(email.email_to).to eq "me@there.com"
      # Newline is added onto the body by the mailer in plain text messages
      expect(email.email_body).to eq "This is a test\n"
      expect(email.email_from).to eq "do-not-reply@vfitrack.net"
      expect(email.email_date).to be_within(1.minute).of Time.zone.now
    end
  end

end

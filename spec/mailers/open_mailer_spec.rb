require 'spec_helper'

describe OpenMailer do

  describe "send_simple_text" do
    it "should send message" do
      OpenMailer.send_simple_text("test@vfitrack.net", "my subject", "my body\ngoes here").deliver!
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq(['test@vfitrack.net'])
      expect(mail.subject).to eq('my subject')
      expect(mail.body.raw_source.strip).to eq("my body\ngoes here")
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
        expect(mail.to).to eq([ agent.email ])
        expect(mail.subject).to eq("[Support Ticket Update]: #{@st.subject}")
        expect(mail.body.raw_source).to include @st.body
      end
      it "should send ticket to generic mailbox when agent is not set" do
        OpenMailer.send_support_ticket_to_agent(@st).deliver!
        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq([ "support@vandegriftinc.com" ])
        expect(mail.subject).to eq("[Support Ticket Update]: #{@st.subject}")
        expect(mail.body.raw_source).to include @st.body
      end
    end

    describe 'send_support_ticket_to_requestor' do
      it "should send ticket to requestor" do
        OpenMailer.send_support_ticket_to_requestor(@st).deliver!

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq([ @requestor.email ])
        expect(mail.subject).to eq("[Support Ticket Update]: #{@st.subject}")
        expect(mail.body.raw_source).to include @st.body
      end
    end
  end

  describe 'send_support_request_to_helpdesk' do
    it "sends request to helpdesk" do
      stub_master_setup
      request = Factory(:support_request, ticket_number: "42", body: "request body", severity: "urgent", referrer_url: "ref url", external_link: "ext link")
      OpenMailer.send_support_request_to_helpdesk("support@vandegriftinc.com", request).deliver!
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["support@vandegriftinc.com"]
      expect(mail.reply_to).to eq [request.user.email]
      expect(mail.subject).to eq "[Support Request ##{request.ticket_number} (test)]"
      expect(mail.body).to include request.user.full_name
      expect(mail.body).to include "request body"
      expect(mail.body).to include "ref url"
      expect(mail.body).to include "(test)"
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
      expect(m.to.first).to eq("example@example.com")
      expect(m.subject).to eq("[VFI Track] Ack File Processing Error")
      expect(m.attachments.size).to eq(1)

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
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(@bucket,@s3_path).and_return(@tempfile)
    end
    after :each do
      @tempfile.close!
    end
    it "should attach file from s3" do
      OpenMailer.send_s3_file(@user, @to, @cc, @subject, @body, @bucket, @s3_path).deliver

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq([@to])
      expect(mail.cc).to eq([@cc])
      expect(mail.subject).to eq(@subject)
      expect(mail.attachments[@filename]).not_to be_nil
      pa = mail.attachments[@filename]
      expect(pa.content_type).to eq("application/octet-stream; charset=UTF-8")
      expect(pa.read).to eq(@s3_content)

    end
    it "should take attachment_name parameter" do
      alt_name = 'x.y'
      OpenMailer.send_s3_file(@user, @to, @cc, @subject, @body, @bucket, @s3_path,alt_name).deliver
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.attachments[alt_name]).not_to be_nil
    end
  end

  describe "send_registration_request" do
    it "should send email with registration details to support address" do
      fields = { email: "john_doe@acme.com", fname: "John", lname: "Doe", company: "Acme",
                  cust_no: "123456789", contact: "Jane Smith", system_code: "HAL9000"}

      OpenMailer.send_registration_request(fields).deliver!
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["support@vandegriftinc.com"]
      expect(mail.subject).to eq "Registration Request (HAL9000)"
      ["Email: #{fields[:email]}", "First Name: #{fields[:fname]}", "Last Name: #{fields[:lname]}", "Company: #{fields[:company]}", "Customer Number: #{fields[:cust_no]}",
       "Contact: #{fields[:contact]}", "System Code: #{fields[:system_code]}"].each {|f| expect(mail.body).to include f }
    end
  end

  describe OpenMailer::NoOpMailer do
    # This just makes sure the MailDelivery interface is being maintained in our NoOpMailer
    subject { described_class }

    describe "initialize" do
      it "accepts settings hash and makes it available" do
        m = subject.new({settings: true})
        expect(m.settings).to eq({settings: true})
      end
    end

    describe "deliver!" do
      subject { described_class.new({}) }

      it "checks mail and does nothing else" do
        expect(Mail::CheckDeliveryParams).to receive(:check).with("mail").and_return "check"
        expect(subject.deliver! "mail").to eq "check"
      end
    end
  end

  describe "suppress_all_emails?" do
    subject { OpenMailer.send :new }
    before :each do 
      # dev/prod, email enabled
      allow(subject).to receive(:test_env?).and_return false
      allow(MasterSetup).to receive(:email_enabled?).and_return true
    end

    it "returns false if email enabled" do
      expect(subject.send :suppress_all_emails?).to eq false
    end
    
    it "returns false if test_env" do
      allow(subject).to receive(:test_env?).and_return true
      expect(subject.send :suppress_all_emails?).to eq false
    end

    it "returns true if not test_env and email disabled" do
      allow(MasterSetup).to receive(:email_enabled?).and_return false
      allow(subject).to receive(:test_env?).and_return false
      expect(subject.send :suppress_all_emails?).to eq true
    end
  end

  describe "send_simple_html" do
    context "with individual email suppression enabled" do
      it "swallows the email after logging it", email_log: true do
        allow_any_instance_of(OpenMailer).to receive(:suppress_all_emails?).and_return false
        allow(MasterSetup).to receive(:email_enabled?).and_return true

        m = OpenMailer.send_simple_html("example@example.com", "Test subject","<p>Test body</p>", [], {suppressed: true})
        # NoOpMailer is the mechanism used to swallow the emails...it's delivery method just
        # ignores the mail and does nothing.
        expect(m.delivery_method).to be_an_instance_of OpenMailer::NoOpMailer
        email = SentEmail.last
        expect(email).not_to be_nil
        expect(email.email_subject).to eq "Test subject"
        expect(email.suppressed).to eq true
      end
    end
    
    context "with general email suppression enabled" do
      before :each do 
        allow_any_instance_of(OpenMailer).to receive(:suppress_all_emails?).and_return true
        allow(MasterSetup).to receive(:email_enabled?).and_return false
      end

      it "swallows the email after logging it", email_log: true do
        m = OpenMailer.send_simple_html("example@example.com", "Test subject","<p>Test body</p>")
        # NoOpMailer is the mechanism used to swallow the emails...it's delivery method just
        # ignores the mail and does nothing.
        expect(m.delivery_method).to be_an_instance_of OpenMailer::NoOpMailer
        email = SentEmail.last
        expect(email).not_to be_nil
        expect(email.email_subject).to eq "Test subject"
        expect(email.suppressed).to eq true
      end
    end

    it "allows sending additional mail options" do
      # Just check that the cc option is utilized when passed.  The options hash just gets passed directly
      # to the #mail method.
      OpenMailer.send_simple_html("example@example.com", "Test subject","<p>Test body</p>", nil, cc: "test@test.com").deliver!

      m = OpenMailer.deliveries.last
      expect(m.cc).to eq ["test@test.com"]
    end

    it "explodes mailing lists into component email addresses" do
      mailing_list = Factory(:mailing_list, system_code: "MAILING LIST")
      user1 = Factory(:user, email: "me@there.com")
      user2 = Factory(:user, email: "you@there.com")

      mailing_list.email_addresses = [user1.email, user2.email].join(", ").to_str
      OpenMailer.send_simple_html(mailing_list, "Subject","").deliver!

      m = OpenMailer.deliveries.last
      expect(m.to.first).to eq user1.email
      expect(m.to.second).to eq user2.email
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

      expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false
      OpenMailer.send_simple_html("me@there.com", "Subject", "<p>Body</p>", f).deliver

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq(["me@there.com"])
      expect(mail.subject).to eq("Subject")
      expect(mail.body.raw_source).to match("&lt;p&gt;Body&lt;/p&gt;")

      pa = mail.attachments[File.basename(f)]
      expect(pa).not_to be_nil
      expect(pa.read).to eq(File.read(f))
      expect(pa.content_type).to eq("application/octet-stream")
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
        expect(mail.to).to eq(["me@there.com"])
        expect(mail.subject).to eq("Subject")
        expect(mail.body.raw_source).to match("<p>Body</p>")
        expect(mail.attachments.size).to eq(2)

        pa = mail.attachments[File.basename(f)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f))
        expect(pa.content_type).to eq("application/octet-stream; charset=UTF-8")

        pa = mail.attachments[File.basename(f2)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f2))
        expect(pa.content_type).to eq("application/octet-stream; charset=UTF-8")
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

        expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).with(f).and_return true
        expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).with(f2)

        OpenMailer.send_simple_html("me@there.com","Subject","<p>Body</p>".html_safe,[f,f2]).deliver!

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.attachments.size).to eq(1)

        pa = mail.attachments[File.basename(f2)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f2))
        expect(pa.content_type).to match /application\/octet-stream/

        ea = EmailAttachment.all.first
        expect(ea).to be_nil
      end
    end
  end

  it "should not save an email attachment if its extension is not allowed by Postmark" do
    Tempfile.open(["bad_file",".vbs"]) do |f|
      Tempfile.open(["good_file", ".txt"]) do |f2|
        f.binmode
        f << "Content"
        f.flush
        f2.binmode
        f2 << "Content2"
        f2.flush

        OpenMailer.send_simple_html("me@there.com","Subject","<p>Body</p>".html_safe,[f,f2]).deliver!

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.attachments.size).to eq(1)

        pa = mail.attachments[File.basename(f2)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f2))
        expect(pa.content_type).to match /application\/octet-stream/

        ea = EmailAttachment.all.first
        expect(ea).to be_nil
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
        expect_any_instance_of(OpenMailer).to receive(:large_attachment?).with(f).and_return true
        expect_any_instance_of(OpenMailer).to receive(:large_attachment?).with(f2).and_return false
        expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false

        OpenMailer.send_simple_html("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2]).deliver

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.attachments.size).to eq(1)

        pa = mail.attachments[File.basename(f2)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f2))
        expect(pa.content_type).to eq("application/octet-stream")

        ea = EmailAttachment.all.first
        expect(ea).not_to be_nil
        expect(ea.attachment.attached_file_name).to eq(File.basename(f))

        body = <<EMAIL
An attachment named '#{File.basename(f)}' for this message was larger than the maximum system size.
Click <a href='#{OpenMailer::LINK_PROTOCOL}://host.xxx/email_attachments/#{ea.id}'>here</a> to download the attachment directly.
All system attachments are deleted after seven days, please retrieve your attachments promptly.
EMAIL
        expect(mail.body.raw_source).to match(body)
      end
    end
  end

  it "should utilize original_filename method for file attachments" do
    Tempfile.open(["file", "txt"]) do |f|
      f.binmode
      f << "Content"
      Attachment.add_original_filename_method f
      f.original_filename = "test.txt"

      expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false
      OpenMailer.send_simple_html("me@there.com", "Subject", "<p>Body</p>", f).deliver

      mail = ActionMailer::Base.deliveries.pop
      pa = mail.attachments['test.txt']
      expect(pa).not_to be_nil
      expect(pa.read).to eq(File.read(f))
      expect(pa.content_type).to eq("application/octet-stream")
    end
  end

  describe "auto_send_attachments" do
    it "should send html email with an attachment" do
      Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"

        expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false
        OpenMailer.auto_send_attachments("me@there.com", "Subject", "<p>Body\n</p>", f, "Test name", "test@email.com").deliver

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq(["me@there.com"])
        expect(mail.reply_to).to eq(["test@email.com"])
        expect(mail.subject).to eq("Subject")
        expect(mail.body.raw_source).to match("&lt;p&gt;Body<br>&lt;/p&gt;")

        pa = mail.attachments[File.basename(f)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f))
        expect(pa.content_type).to eq("application/octet-stream")
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
          expect(mail.to).to eq(["me@there.com"])
          expect(mail.reply_to).to eq(["test@email.com"])
          expect(mail.subject).to eq("Subject")
          expect(mail.body.raw_source).to match("&lt;p&gt;Body<br>&lt;/p&gt;")
          expect(mail.attachments.size).to eq(2)

          pa = mail.attachments[File.basename(f)]
          expect(pa).not_to be_nil
          expect(pa.read).to eq(File.read(f))
          expect(pa.content_type).to eq("application/octet-stream; charset=UTF-8")

          pa = mail.attachments[File.basename(f2)]
          expect(pa).not_to be_nil
          expect(pa.read).to eq(File.read(f2))
          expect(pa.content_type).to eq("application/octet-stream; charset=UTF-8")
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

          expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).with(f).and_return true
          expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).with(f2)

          OpenMailer.auto_send_attachments("me@there.com","Subject","<p>Body</p>".html_safe,[f,f2], "Test name", "test@email.com").deliver!

          mail = ActionMailer::Base.deliveries.pop
          expect(mail.attachments.size).to eq(1)

          pa = mail.attachments[File.basename(f2)]
          expect(pa).not_to be_nil
          expect(pa.read).to eq(File.read(f2))
          expect(pa.content_type).to match /application\/octet-stream/

          ea = EmailAttachment.all.first
          expect(ea).to be_nil
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
          expect_any_instance_of(OpenMailer).to receive(:large_attachment?).with(f).and_return true
          expect_any_instance_of(OpenMailer).to receive(:large_attachment?).with(f2).and_return false
          expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false

          OpenMailer.auto_send_attachments("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2], "Test name", "test@email.com").deliver

          mail = ActionMailer::Base.deliveries.pop
          expect(mail.attachments.size).to eq(1)

          pa = mail.attachments[File.basename(f2)]
          expect(pa).not_to be_nil
          expect(pa.read).to eq(File.read(f2))
          expect(pa.content_type).to eq("application/octet-stream")

          ea = EmailAttachment.all.first
          expect(ea).not_to be_nil
          expect(ea.attachment.attached_file_name).to eq(File.basename(f))

          body = <<EMAIL
An attachment named '#{File.basename(f)}' for this message was larger than the maximum system size.
Click <a href='#{OpenMailer::LINK_PROTOCOL}://host.xxx/email_attachments/#{ea.id}'>here</a> to download the attachment directly.
All system attachments are deleted after seven days, please retrieve your attachments promptly.
EMAIL
          expect(mail.body.raw_source).to match(body)
        end
      end
    end

    it "should utilize original_filename method for file attachments" do
      Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"
        Attachment.add_original_filename_method f
        f.original_filename = "test.txt"

        expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false
        OpenMailer.auto_send_attachments("me@there.com", "Subject", "<p>Body</p>", f, "Test name", "test@email.com").deliver

        mail = ActionMailer::Base.deliveries.pop
        pa = mail.attachments['test.txt']
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f))
        expect(pa.content_type).to eq("application/octet-stream")
      end
    end

    it "should include the full name and email of the attachment sender" do
      Tempfile.open(["file","txt"]) do |f|
        expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false
        OpenMailer.auto_send_attachments("me@there.com", "Subject","<p>Body</p>", f, "Test name", "test@email.com").deliver

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.body).to match(/by Test name \(test\@email\.com\)/)
      end
    end
  end

  describe "send_generic_exception", email_log: true do
    it "should send an exception email (even if instance configured to suppress it)" do
      allow_any_instance_of(OpenMailer).to receive(:suppress_all_emails?).and_return true

      error = StandardError.new "Test"
      error.set_backtrace ["Backtrace", "Line 1", "Line 2"]

      Tempfile.open(["file", "txt"]) do |f|
        f << "Test File"
        f.flush
        f.rewind

        OpenMailer.send_generic_exception(error, ["My Message"], nil, nil, [f.path]).deliver

        mail = ActionMailer::Base.deliveries.pop
        source = mail.body.raw_source
        expect(source).to include("Error: #{error}")
        expect(source).to include("Message: #{error.message}")
        expect(source).to include("Master UUID: #{MasterSetup.get.uuid}")
        expect(source).to include("Root: #{Rails.root.to_s}")
        expect(source).to include("Host: #{Socket.gethostname}")
        expect(source).to include("Process ID: #{Process.pid}")
        expect(source).to include("Additional Messages:")
        expect(source).to include("My Message")
        expect(source).to include("Backtrace:")
        expect(source).to include(error.backtrace.join("\n"))

        expect(mail.attachments[File.basename(f.path)].read).to eq "Test File"

        sent_email = SentEmail.last
        expect(sent_email.suppressed).to eq false
      end
    end

    it "should send an exception email using argument overrides" do
      # error message and backtrace should come from the method arguments and not the exception itself
      error = StandardError.new "Test"
      error.set_backtrace ["Backtrace", "Line 1", "Line 2"]

      OpenMailer.send_generic_exception(error, ["My Message"], "Override Message", ["Fake", "Backtrace"]).deliver

      mail = ActionMailer::Base.deliveries.pop
      source = mail.body.raw_source
      expect(source).not_to include(error.backtrace.join("\n"))
      expect(source).not_to include("Message: #{error.message}")
      expect(source).to include("Fake\nBacktrace")
      expect(source).to include("Message: Override Message")
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

        expect_any_instance_of(OpenMailer).to receive(:large_attachment?).with(f.path).and_return true

        OpenMailer.send_generic_exception(e, ["Test", "Test2"], "Error Message", nil, [f.path]).deliver

        mail = ActionMailer::Base.deliveries.pop
        pa = expect(mail.attachments.size).to eq(0)

        ea = EmailAttachment.all.first
        expect(ea).not_to be_nil
        expect(ea.attachment.attached_file_name).to eq(File.basename(f))

        body = <<EMAIL
An attachment named '#{File.basename(f)}' for this message was larger than the maximum system size.
Click <a href='http://host.xxx/email_attachments/#{ea.id}'>here</a> to download the attachment directly.
All system attachments are deleted after seven days, please retrieve your attachments promptly.
EMAIL
        expect(mail.body.raw_source).to match(body)
      end
    end

    it "should truncate message subject at 2000 chars" do
      message_subject = "This is a subject."
      message_subject += message_subject while message_subject.length < 200
      e = (raise "Error" rescue $!)
      m = OpenMailer.send_generic_exception(e, ["Test", "Test2"], message_subject)
      expect(m.subject).to eq ("[VFI Track Exception] - #{message_subject}")[0..99]
    end

    context "in development environment" do

      before :each do 
        allow_any_instance_of(OpenMailer).to receive(:development_env?).and_return true
      end

      it "redirects message to 'exception_email_to' config address" do
        expect(MasterSetup).to receive(:config_value).with("exception_email_to", default: "you-must-set-exception_email_to-in-vfitrack-config@vandegriftinc.com").and_return "developer@here.com"
        error = StandardError.new "Test"
        error.set_backtrace ["Backtrace", "Line 1", "Line 2"]

        m = OpenMailer.send_generic_exception(error)
        expect(m.to).to eq ["developer@here.com"]
      end
    end
  end

  describe "send_invite" do
    before :each do
      MasterSetup.get.update_attributes request_host: "localhost"
      @user = Factory(:user, first_name: "Joe", last_name: "Schmoe", email: "me@there.com")
    end

    it "should send an invite email" do
      pwd = "password"
      mail = OpenMailer.send_invite @user, pwd
      expect(mail.subject).to eq "[VFI Track] Welcome, Joe Schmoe!"
      expect(mail.to).to eq [@user.email]

      expect(mail.body.raw_source).to match /Username: #{@user.username}/
      expect(mail.body.raw_source).to match /Temporary Password: #{pwd}/
      expect(mail.body.raw_source).to match /#{url_for(host: MasterSetup.get.request_host, controller: 'user_sessions', action: 'new', protocol: OpenMailer::LINK_PROTOCOL)}/
    end

    context "with general email suppression enabled" do
      before :each do 
        allow_any_instance_of(OpenMailer).to receive(:suppress_all_emails?).and_return true
      end

      it "is not affected by email suppression enabled" do
        pwd = "password"
        mail = OpenMailer.send_invite @user, pwd
        expect(mail.subject).to eq "[VFI Track] Welcome, Joe Schmoe!"
        expect(mail.to).to eq [@user.email]

        expect(mail.body.raw_source).to match /Username: #{@user.username}/
        expect(mail.body.raw_source).to match /Temporary Password: #{pwd}/
        expect(mail.body.raw_source).to match /#{url_for(host: MasterSetup.get.request_host, controller: 'user_sessions', action: 'new', protocol: OpenMailer::LINK_PROTOCOL)}/

        expect(mail.delivery_method).to be_an_instance_of OpenMailer::LoggingMailerProxy
      end
    end
  end

  describe "send_uploaded_items" do
    before :each do
      @user = Factory(:user, first_name: "Joe", last_name: "Schmoe", email: "me@there.com")
    end

    it "should send imported file data" do
      data = "This is my data, there are many like it but this one is mine."
      imported_file = double("ImportedFile")
      allow(imported_file).to receive(:attached_file_name).and_return "test.txt"
      allow(imported_file).to receive(:module_type).and_return "Product"

      m = OpenMailer.send_uploaded_items "you@there.com", imported_file, data, @user
      expect(m.to).to eq ["you@there.com"]
      expect(m.reply_to).to eq [@user.email]
      expect(m.subject).to eq "[VFI Track] Product File Result"

      expect(m.attachments["test.txt"]).not_to be_nil
      expect(m.attachments["test.txt"].read).to eq data
    end

    it "should not add attachment if data is too large" do
      data = "This is my data, there are many like it but this one is mine."
      imported_file = double("ImportedFile")
      allow(imported_file).to receive(:attached_file_name).and_return "test.txt"
      allow(imported_file).to receive(:module_type).and_return "Product"

      expect_any_instance_of(OpenMailer).to receive(:save_large_attachment).and_return true

      m = OpenMailer.send_uploaded_items "you@there.com", imported_file, data, @user
      expect(m.attachments["test.txt"]).to be_nil
    end
  end

  describe "send_high_priority_tasks" do

    before :each do
      @u1 = Factory(:user, email: "me@there.com")
      @pd1 = Factory(:project_deliverable, assigned_to: @u1, description: "PD1 Description")
      OpenMailer.send_high_priority_tasks(@u1, [@pd1]).deliver!
    end

    it "should be sent to the correct user" do
      expect(OpenMailer.deliveries.pop.to.first).to eq("me@there.com")
    end

    it "should have a subject line of the correct form" do
      expect(OpenMailer.deliveries.pop.subject).to match(/\[VFI Track\] Task Priorities \- \d{2}\/\d{2}\/\d{2}/)
    end

    it "should have the project deliverable descriptions in the body" do
      expect(OpenMailer.deliveries.pop.body).to match(/PD1 Description/)
    end

  end

  describe "send_survey_invite" do
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

  describe "send_survey_reminder" do

    it "sends email with specified recipients, subject & body, with a link to the survey" do
      sr = Factory(:survey_response)

      stub_master_setup
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

  describe "send_search_result_manually" do
    before(:each) { @u = Factory(:user, email: "me@here.com")}

    it "sends email with to, reply_to, subject, body, and attachment" do
       Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"

        expect_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false
        OpenMailer.send_search_result_manually("you@there.com", "Subject", "<p>Body</p>", f.path, @u).deliver!

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq(["you@there.com"])
        expect(mail.reply_to).to eq(["me@here.com"])
        expect(mail.subject).to eq("Subject")
        expect(mail.body.raw_source).to match("&lt;p&gt;Body&lt;/p&gt;")

        pa = mail.attachments[File.basename(f)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f))
        expect(pa.content_type).to eq("application/octet-stream")
      end

    end

  end

  describe "send_search_bad_email" do
    it "sends email with to, subject, body" do
      stub_master_setup
      srch = Factory(:search_setup, name: "srch name")
      OpenMailer.send_search_bad_email("tufnel@stonehenge.biz", srch, "Your search has an invalid email!").deliver!
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq (["tufnel@stonehenge.biz"])
      expect(mail.subject).to eq("[VFI Track] Search Transmission Failure")
      expect(mail.body.raw_source).to include "Your search has an invalid email!"
      expect(mail.body.raw_source).to include "srch name"
      expect(mail.body.raw_source).to include "https://localhost:3000/advanced_search/#{srch.id}"
    end
  end

  describe "log_email", email_log: true do

    it "saves outgoing e-mail fields and attachments" do
      sub = "what it's about"
      to = "john@doe.com; me@there.com, you@here.com"
      body = "Lorem ipsum dolor sit amet, consectetur adipisicing elit."
      allow_any_instance_of(OpenMailer).to receive(:blank_attachment?).and_return false

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

  describe "deliver", email_log: true do 
    # This makes sure our internal proxy class is being used as the primary delivery method for emails and that
    # it's being set up correctly.
    it "utilizes LoggingMailerProxy class for deliveries" do
      mail = OpenMailer.send_simple_text("me@there.com", "Subject", "Body")
      delivery_method = mail.delivery_method
      expect(delivery_method).to be_a OpenMailer::LoggingMailerProxy
      expect(delivery_method.original_delivery_method).not_to be_nil
      expect(delivery_method.sent_email).not_to be_nil
      expect(delivery_method.sent_email.persisted?).to eq true
      expect(delivery_method.settings).not_to be_nil
    end
  end


  describe OpenMailer::LoggingMailerProxy do

    let (:mail) {
      instance_double(Mail::Message)
    }

    let (:original_delivery_method) {
      d = double("DeliveryMethod")
      allow(d).to receive(:deliver!).with(mail).and_return "Delivered"
      d
    }

    let (:sent_email) {
      SentEmail.new 
    }

    let (:original_config) {
      {config: "config"}
    }

    let (:settings) {
      c = original_config.dup
      c[:original_delivery_method] = original_delivery_method
      c[:sent_email] = sent_email
      c
    }

    describe "intiialize" do 
      it "extracts settings values" do
        p = OpenMailer::LoggingMailerProxy.new settings
        expect(settings[:original_delivery_method]).to be_nil
        expect(settings[:sent_email]).to be_nil
        expect(p.original_delivery_method).to eq original_delivery_method
        expect(p.sent_email).to eq sent_email
        expect(p.settings).to eq original_config
      end
    end

    describe "deliver!" do
      subject { described_class.new settings }

      it "calls through to the original delivery methods deliver! method" do
        expect(subject.deliver! mail).to eq "Delivered"
      end

      it "logs any error messages raised against the sent_email" do
        expect(original_delivery_method).to receive(:deliver!).and_raise "Testing Error"

        expect { subject.deliver! mail }.to raise_error "Testing Error"
        expect(sent_email).to be_persisted
        expect(sent_email.delivery_error).to eq "Testing Error"
      end

      it "swallows Postmark::InvalidMessageError" do
        expect(original_delivery_method).to receive(:deliver!).and_raise Postmark::InvalidMessageError, "Testing Error"
        expect(subject.deliver! mail).to be_nil
        expect(sent_email).to be_persisted
        expect(sent_email.delivery_error).to eq "Testing Error"
      end
    end
  end
end

describe OpenMailer do

  let! (:master_setup) do
    ms = stub_master_setup
    allow(ms).to receive(:request_host).and_return "host.xxx"
    ms
  end

  describe "send_simple_text" do
    it "sends message" do
      described_class.send_simple_text("test@vfitrack.net", "my subject", "my body\ngoes here").deliver_now
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq(['test@vfitrack.net'])
      expect(mail.subject).to eq('my subject')
      expect(mail.body.raw_source.strip).to eq("my body\r\ngoes here")
    end
  end

  context "support tickets" do

    let(:requestor) { FactoryBot(:user) }
    let(:st) { SupportTicket.new(requestor: requestor, subject: "SUB", body: "BOD") }

    describe 'send_support_ticket_to_agent' do
      it "sends ticket to agent when agent is set" do
        agent = FactoryBot(:user)
        st.agent = agent
        described_class.send_support_ticket_to_agent(st).deliver_now
        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq([agent.email])
        expect(mail.subject).to eq("[Support Ticket Update]: #{st.subject}")
        expect(mail.body.raw_source).to include st.body
      end

      it "sends ticket to generic mailbox when agent is not set" do
        described_class.send_support_ticket_to_agent(st).deliver_now
        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq(["support@vandegriftinc.com"])
        expect(mail.subject).to eq("[Support Ticket Update]: #{st.subject}")
        expect(mail.body.raw_source).to include st.body
      end
    end

    describe 'send_support_ticket_to_requestor' do
      it "sends ticket to requestor" do
        described_class.send_support_ticket_to_requestor(st).deliver_now

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq([requestor.email])
        expect(mail.subject).to eq("[Support Ticket Update]: #{st.subject}")
        expect(mail.body.raw_source).to include st.body
      end
    end
  end

  describe 'send_support_request_to_helpdesk' do
    it "sends request to helpdesk" do
      stub_master_setup
      request = FactoryBot(:support_request, ticket_number: "42", body: "request body", severity: "urgent", referrer_url: "ref url", external_link: "ext link")
      described_class.send_support_request_to_helpdesk("support@vandegriftinc.com", request).deliver_now
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
    let! (:tempfile) do
      tempfile = Tempfile.new ["s3_content", ".txt"]
      tempfile.binmode
      tempfile << "Content of a tempfile"
      tempfile.rewind
      tempfile
    end

    after do
      tempfile.close!
    end

    it "attaches file for ack file exceptions" do
      expect_any_instance_of(described_class).to receive(:explode_group_and_mailing_lists).with("example@example.com", "TO").and_return "mail@there.com"
      described_class.send_ack_file_exception("example@example.com", ["Error 1", "Error 2", "Error 3"], tempfile, "s3_content.txt", "Sync code").deliver_now
      m = described_class.deliveries.pop
      expect(m.to.first).to eq("mail@there.com")
      expect(m.subject).to eq("[VFI Track] Ack File Processing Error")
      expect(m.attachments.size).to eq(1)
    end
  end

  describe 'send_s3_file' do
    let(:user) { FactoryBot(:user) }
    let(:to) { 'a@b.com' }
    let(:cc) { 'cc@cc.com' }
    let(:subject) { 'my subject' }
    let(:body) { 'my body' }
    let(:filename) { 'a.xls' }
    let(:bucket) { 'mybucket' }
    let(:s3_path) { "my/path/#{filename}" }
    let(:s3_content) { "some content here" }
    let(:tempfile) do
      tempfile = Tempfile.new ["s3_content", ".txt"]
      tempfile.binmode
      tempfile << s3_content
      tempfile.rewind
      tempfile
    end

    after do
      tempfile.close!
    end

    it "attaches file from s3" do
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(bucket, s3_path).and_return(tempfile)
      described_class.send_s3_file(user, to, cc, subject, body, bucket, s3_path).deliver_now

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq([to])
      expect(mail.cc).to eq([cc])
      expect(mail.subject).to eq(subject)
      expect(mail.attachments[filename]).not_to be_nil
      pa = mail.attachments[filename]
      expect(pa.content_type).to eq("application/vnd.ms-excel")
      expect(pa.read).to eq(s3_content)

    end

    it "takes attachment_name parameter" do
      expect(OpenChain::S3).to receive(:download_to_tempfile).with(bucket, s3_path).and_return(tempfile)
      alt_name = 'x.y'
      described_class.send_s3_file(user, to, cc, subject, body, bucket, s3_path, alt_name).deliver_now
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.attachments[alt_name]).not_to be_nil
    end
  end

  describe "send_registration_request" do
    it "sends email with registration details to support address" do
      described_class.send_registration_request("john_doe@acme.com", "John", "Doe", "Acme", "123456789", "Jane Smith", "HAL9000").deliver_now
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["support@vandegriftinc.com"]
      expect(mail.subject).to eq "Registration Request (HAL9000)"
      ["Email: john_doe@acme.com", "First Name: John", "Last Name: Doe", "Company: Acme", "Customer Number: 123456789",
       "Contact: Jane Smith", "System Code: HAL9000"].each {|f| expect(mail.body).to include f }
    end
  end

  describe "suppress_all_emails?" do
    subject { described_class.send :new }

    before do
      # dev/prod, email enabled
      allow(MasterSetup).to receive(:test_env?).and_return false
      allow(MasterSetup).to receive(:email_enabled?).and_return true
    end

    it "returns false if email enabled" do
      expect(subject.send(:suppress_all_emails?)).to eq false
    end

    it "returns false if test_env" do
      allow(MasterSetup).to receive(:test_env?).and_return true
      expect(subject.send(:suppress_all_emails?)).to eq false
    end

    it "returns true if not test_env and email disabled" do
      allow(MasterSetup).to receive(:email_enabled?).and_return false
      allow(MasterSetup).to receive(:test_env?).and_return false
      expect(subject.send(:suppress_all_emails?)).to eq true
    end
  end

  describe "send_simple_html" do
    context "with individual email suppression enabled" do
      it "swallows the email after logging it", email_log: true do
        allow_any_instance_of(described_class).to receive(:suppress_all_emails?).and_return false
        allow(MasterSetup).to receive(:email_enabled?).and_return true

        m = described_class.send_simple_html("example@example.com", "Test subject", "<p>Test body</p>", [], {suppressed: true})
        expect(m.perform_deliveries).to eq false
        email = SentEmail.last
        expect(email).not_to be_nil
        expect(email.email_subject).to eq "Test subject"
        expect(email.suppressed).to eq true
      end
    end

    context "with general email suppression enabled" do
      before do
        allow_any_instance_of(described_class).to receive(:suppress_all_emails?).and_return true
        allow(MasterSetup).to receive(:email_enabled?).and_return false
      end

      it "swallows the email after logging it", email_log: true do
        m = described_class.send_simple_html("example@example.com", "Test subject", "<p>Test body</p>")
        expect(m.perform_deliveries).to eq false
        email = SentEmail.last
        expect(email).not_to be_nil
        expect(email.email_subject).to eq "Test subject"
        expect(email.suppressed).to eq true
      end
    end

    it "allows sending additional mail options" do
      # Just check that the cc option is utilized when passed.  The options hash just gets passed directly
      # to the #mail method.
      described_class.send_simple_html("example@example.com", "Test subject", "<p>Test body</p>", nil, cc: "test@test.com").deliver_now

      m = described_class.deliveries.last
      expect(m.cc).to eq ["test@test.com"]
    end

    it "explodes mailing lists into component email addresses" do
      mailing_list = FactoryBot(:mailing_list, system_code: "MAILING LIST")
      user1 = FactoryBot(:user, email: "me@there.com")
      user2 = FactoryBot(:user, email: "you@there.com")

      mailing_list.email_addresses = [user1.email, user2.email].join(", ").to_str
      described_class.send_simple_html(mailing_list, "Subject", "").deliver_now

      m = described_class.deliveries.last
      expect(m.to.first).to eq user1.email
      expect(m.to.second).to eq user2.email
    end

    it "explodes groups into component email addresses" do
      group = FactoryBot(:group, system_code: "GROUP")
      user1 = FactoryBot(:user, email: "me@there.com")
      user2 = FactoryBot(:user, email: "you@there.com")

      group.users << user1
      group.users << user2

      described_class.send_simple_html(group, "Subject", "").deliver_now

      m = described_class.deliveries.last
      expect(m.to.first).to eq user1.email
      expect(m.to.second).to eq user2.email
    end
  end

  it "sends html email with an attachment" do
    Tempfile.open(["file", "txt"]) do |f|
      f.binmode
      f << "Content"

      expect_any_instance_of(described_class).to receive(:blank_attachment?).and_return false
      described_class.send_simple_html("me@there.com", "Subject", "<p>Body</p>", f).deliver_now

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

  it "sends html email with multiple attachments" do
    Tempfile.open(["file", "txt"]) do |f|
      f.binmode
      f << "Content"

      Tempfile.open(["file2", "txt"]) do |f2|
        f2.binmode
        f2 << "Content2"
        f2.flush
        f.flush

        described_class.send_simple_html("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2]).deliver_now

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq(["me@there.com"])
        expect(mail.subject).to eq("Subject")
        expect(mail.body.raw_source).to match("<p>Body</p>")
        expect(mail.attachments.size).to eq(2)

        pa = mail.attachments[File.basename(f)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f))
        expect(pa.content_type).to eq("application/octet-stream")

        pa = mail.attachments[File.basename(f2)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f2))
        expect(pa.content_type).to eq("application/octet-stream")
      end
    end
  end

  it "does not save an email attachment if the attachment is empty" do
    Tempfile.open(["file", "txt"]) do |f|
      Tempfile.open(["file2", "txt"]) do |f2|
        f.binmode
        f << "Content"
        f2.binmode
        f2 << "Content2"
        f2.flush

        expect_any_instance_of(described_class).to receive(:blank_attachment?).with(f).and_return true
        expect_any_instance_of(described_class).to receive(:blank_attachment?).with(f2)

        described_class.send_simple_html("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2]).deliver_now

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.attachments.size).to eq(1)

        pa = mail.attachments[File.basename(f2)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f2))
        expect(pa.content_type).to match %r{application/octet-stream}

        ea = EmailAttachment.all.first
        expect(ea).to be_nil
      end
    end
  end

  it "does not save an email attachment if its extension is not allowed by Postmark" do
    Tempfile.open(["bad_file", ".vbs"]) do |f|
      Tempfile.open(["good_file", ".txt"]) do |f2|
        f.binmode
        f << "Content"
        f.flush
        f2.binmode
        f2 << "Content2"
        f2.flush

        described_class.send_simple_html("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2]).deliver_now

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.attachments.size).to eq(1)

        pa = mail.attachments[File.basename(f2)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f2))
        expect(pa.content_type).to match %r{text/plain}

        ea = EmailAttachment.all.first
        expect(ea).to be_nil
      end
    end
  end

  it "saves an email attachment if the attachment is too large" do
    # One attachment should get mailed, the second should get saved off and a link for
    # downloading added to the email
    Tempfile.open(["file", "txt"]) do |f|
      Tempfile.open(["file2", "txt"]) do |f2|
        f.binmode
        f << "Content"
        f2.binmode
        f2 << "Content2"

        # This chain means f is too large, but f2 is neither too large nor blank. Thus we should have 1 attachment.
        expect_any_instance_of(described_class).to receive(:large_attachment?).with(f).and_return true
        expect_any_instance_of(described_class).to receive(:large_attachment?).with(f2).and_return false
        expect_any_instance_of(described_class).to receive(:blank_attachment?).and_return false

        described_class.send_simple_html("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2]).deliver_now

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.attachments.size).to eq(1)

        pa = mail.attachments[File.basename(f2)]
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f2))
        expect(pa.content_type).to eq("application/octet-stream")

        ea = EmailAttachment.all.first
        expect(ea).not_to be_nil
        expect(ea.attachment.attached_file_name).to eq(File.basename(f))
        expect(mail.body.raw_source).to match("Click <a href='https://localhost:3000/email_attachments/#{ea.id}'>here</a> to download the attachment directly.")
      end
    end
  end

  it "utilizes original_filename method for file attachments" do
    Tempfile.open(["file", "txt"]) do |f|
      f.binmode
      f << "Content"
      Attachment.add_original_filename_method f
      f.original_filename = "test.txt"

      expect_any_instance_of(described_class).to receive(:blank_attachment?).and_return false
      described_class.send_simple_html("me@there.com", "Subject", "<p>Body</p>", f).deliver_now

      mail = ActionMailer::Base.deliveries.pop
      pa = mail.attachments['test.txt']
      expect(pa).not_to be_nil
    end
  end

  describe "auto_send_attachments" do
    it "sends html email with an attachment" do
      Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"

        expect_any_instance_of(described_class).to receive(:blank_attachment?).and_return false
        described_class.auto_send_attachments("me@there.com", "Subject", "<p>Body\n</p>", f, "Test name", "test@email.com").deliver_now

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

    it "sends html email with multiple attachments" do
      Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"

        Tempfile.open(["file2", "txt"]) do |f2|
          f2.binmode
          f2 << "Content2"
          f2.flush
          f.flush

          described_class.auto_send_attachments("me@there.com", "Subject", "<p>Body\n</p>", [f, f2], "Test name", "test@email.com").deliver_now

          mail = ActionMailer::Base.deliveries.pop
          expect(mail.to).to eq(["me@there.com"])
          expect(mail.reply_to).to eq(["test@email.com"])
          expect(mail.subject).to eq("Subject")
          expect(mail.body.raw_source).to match("&lt;p&gt;Body<br>&lt;/p&gt;")
          expect(mail.attachments.size).to eq(2)

          pa = mail.attachments[File.basename(f)]
          expect(pa).not_to be_nil
          expect(pa.read).to eq(File.read(f))
          expect(pa.content_type).to eq("application/octet-stream")

          pa = mail.attachments[File.basename(f2)]
          expect(pa).not_to be_nil
          expect(pa.read).to eq(File.read(f2))
          expect(pa.content_type).to eq("application/octet-stream")
        end
      end
    end

    it "does not save an email attachment if the attachment is empty" do
      Tempfile.open(["file", "txt"]) do |f|
        Tempfile.open(["file2", "txt"]) do |f2|
          f.binmode
          f << "Content"
          f2.binmode
          f2 << "Content2"
          f2.flush

          expect_any_instance_of(described_class).to receive(:blank_attachment?).with(f).and_return true
          expect_any_instance_of(described_class).to receive(:blank_attachment?).with(f2)

          described_class.auto_send_attachments("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2], "Test name", "test@email.com").deliver_now

          mail = ActionMailer::Base.deliveries.pop
          expect(mail.attachments.size).to eq(1)

          pa = mail.attachments[File.basename(f2)]
          expect(pa).not_to be_nil
          expect(pa.read).to eq(File.read(f2))
          expect(pa.content_type).to match %r{application/octet-stream}

          ea = EmailAttachment.all.first
          expect(ea).to be_nil
        end
      end
    end

    it "saves an email attachment if the attachment is too large" do
      # One attachment should get mailed, the second should get saved off and a link for
      # downloading added to the email
      Tempfile.open(["file", "txt"]) do |f|
        Tempfile.open(["file2", "txt"]) do |f2|
          f.binmode
          f << "Content"
          f2.binmode
          f2 << "Content2"

          # This chain means f is too large, but f2 is neither too large nor blank. Thus we should have 1 attachment.
          expect_any_instance_of(described_class).to receive(:large_attachment?).with(f).and_return true
          expect_any_instance_of(described_class).to receive(:large_attachment?).with(f2).and_return false
          expect_any_instance_of(described_class).to receive(:blank_attachment?).and_return false

          described_class.auto_send_attachments("me@there.com", "Subject", "<p>Body</p>".html_safe, [f, f2], "Test name", "test@email.com").deliver_now

          mail = ActionMailer::Base.deliveries.pop
          expect(mail.attachments.size).to eq(1)

          pa = mail.attachments[File.basename(f2)]
          expect(pa).not_to be_nil
          expect(pa.read).to eq(File.read(f2))
          expect(pa.content_type).to eq("application/octet-stream")

          ea = EmailAttachment.all.first
          expect(ea).not_to be_nil
          expect(ea.attachment.attached_file_name).to eq(File.basename(f))

          expect(mail.body.raw_source).to match("Click <a href='https://localhost:3000/email_attachments/#{ea.id}'>here</a> to download the attachment directly.")
        end
      end
    end

    it "utilizes original_filename method for file attachments" do
      Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"
        Attachment.add_original_filename_method f
        f.original_filename = "test.txt"

        expect_any_instance_of(described_class).to receive(:blank_attachment?).and_return false
        described_class.auto_send_attachments("me@there.com", "Subject", "<p>Body</p>", f, "Test name", "test@email.com").deliver_now

        mail = ActionMailer::Base.deliveries.pop
        pa = mail.attachments['test.txt']
        expect(pa).not_to be_nil
        expect(pa.read).to eq(File.read(f))
        expect(pa.content_type).to eq("text/plain")
      end
    end

    it "includes the full name and email of the attachment sender" do
      Tempfile.open(["file", "txt"]) do |f|
        expect_any_instance_of(described_class).to receive(:blank_attachment?).and_return false
        described_class.auto_send_attachments("me@there.com", "Subject", "<p>Body</p>", f, "Test name", "test@email.com").deliver_now

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.body).to match(/by Test name \(test\@email\.com\)/)
      end
    end
  end

  describe "send_generic_exception", email_log: true do
    let! (:master_setup) do
      ms = stub_master_setup
      allow(MasterSetup).to receive(:instance_directory).and_return "/path/to/root"
      allow(ms).to receive(:uuid).and_return "uuid"
      allow(MasterSetup).to receive(:hostname).and_return "hostname"
      ms
    end

    let! (:instance_information) do
      allow(InstanceInformation).to receive(:server_role).and_return "Test Role"
      allow(InstanceInformation).to receive(:server_name).and_return "test-server"
    end

    it "sends an exception email (even if instance configured to suppress it)" do
      allow_any_instance_of(described_class).to receive(:suppress_all_emails?).and_return true

      error = StandardError.new "Test"
      error.set_backtrace ["Backtrace", "Line 1", "Line 2"]

      Tempfile.open(["file", "txt"]) do |f|
        f << "Test File"
        f.flush
        f.rewind

        now = Time.zone.now
        Timecop.freeze(now) do
          described_class.send_generic_exception(error, ["My Message"], nil, nil, [f.path]).deliver_now
        end

        mail = ActionMailer::Base.deliveries.pop
        source = mail.body.raw_source
        expect(source).to include("https://localhost:3000/master_setups")
        expect(source).to include("Error: #{error}")
        expect(source).to include("Message: #{error.message}")
        expect(source).to include("Master UUID: uuid")
        expect(source).to include("Time: #{now.in_time_zone("America/New_York").strftime("%Y-%m-%d %H:%M:%S %Z %z")}")
        expect(source).to include("Root: /path/to/root")
        expect(source).to include("Host: hostname")
        expect(source).to include("Server Name: test-server")
        expect(source).to include("Server Role: Test Role")
        expect(source).to include("Process ID: #{Process.pid}")
        expect(source).to include("Additional Messages:")
        expect(source).to include("My Message")
        expect(source).to include("Backtrace:")
        expect(source).to include(error.backtrace.join("\r\n"))

        expect(mail.attachments[File.basename(f.path)].read).to eq "Test File"

        sent_email = SentEmail.last
        expect(sent_email.suppressed).to eq false
      end
    end

    it "sends an exception email using argument overrides" do
      # error message and backtrace should come from the method arguments and not the exception itself
      error = StandardError.new "Test"
      error.set_backtrace ["Backtrace", "Line 1", "Line 2"]

      described_class.send_generic_exception(error, ["My Message"], "Override Message", ["Fake", "Backtrace"]).deliver_now

      mail = ActionMailer::Base.deliveries.pop
      source = mail.body.raw_source
      expect(source).not_to include(error.backtrace.join("\n"))
      expect(source).not_to include("Message: #{error.message}")
      expect(source).to include("Fake\r\nBacktrace")
      expect(source).to include("Message: Override Message")
    end

    it "sends an exception email with a large attachment warning" do
      Tempfile.open(["file", "txt"]) do |f|
        begin
          raise "Error"
        rescue StandardError => e
          e
        end
        f.binmode
        f << "Test"

        expect_any_instance_of(described_class).to receive(:large_attachment?).with(f.path).and_return true

        described_class.send_generic_exception(e, ["Test", "Test2"], "Error Message", nil, [f.path]).deliver_now

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.attachments.size).to eq(0)

        ea = EmailAttachment.all.first
        expect(ea).not_to be_nil
        expect(ea.attachment.attached_file_name).to eq(File.basename(f))

        expect(mail.body.raw_source).to include("An attachment named '#{File.basename(f)}' for this message was larger than the maximum system size.")
        expect(mail.body.raw_source).to include("Click <a href='https://localhost:3000/email_attachments/#{ea.id}'>here</a> to download the attachment directly.")
      end
    end

    it "truncates message subject at 2000 chars" do
      message_subject = "This is a subject."
      message_subject += message_subject while message_subject.length < 200
      e = (begin
             raise "Error"
           rescue StandardError => e
             e
           end)
      m = described_class.send_generic_exception(e, ["Test", "Test2"], message_subject)
      expect(m.subject).to eq "[VFI Track Exception] - #{message_subject}"[0..99]
    end

    it "handles String objects in place of actual exception object" do
      described_class.send_generic_exception("ExceptionClass").deliver_now
      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.body.raw_source).to include("Error: ExceptionClass")
    end

    context "in development environment" do
      it "redirects message to 'exception_email_to' config address" do
        expect(MasterSetup).to receive(:development_env?).and_return true
        default = "you-must-set-exception_email_to-in-vfitrack-config@vandegriftinc.com"
        expect(MasterSetup).to receive(:config_value).with("exception_email_to", default: default)
                                                     .and_return "developer@here.com"
        error = StandardError.new "Test"
        error.set_backtrace ["Backtrace", "Line 1", "Line 2"]

        described_class.send_generic_exception(error).deliver_now
        m = ActionMailer::Base.deliveries.first
        expect(m.to).to eq ["developer@here.com"]
      end
    end
  end

  describe "send_invite" do
    let(:user) { FactoryBot(:user, first_name: "Joe", last_name: "Schmoe", email: "me@there.com") }

    it "sends an invite email" do
      allow(master_setup).to receive(:request_host).and_return "localhost"
      pwd = "password"
      mail = described_class.send_invite user, pwd
      expect(mail.subject).to eq "[VFI Track] Welcome, Joe Schmoe!"
      expect(mail.to).to eq [user.email]

      expect(mail.body.raw_source).to match(/Username: #{user.username}/)
      expect(mail.body.raw_source).to match(/Temporary Password: #{pwd}/)
      expect(mail.body.raw_source).to match %r{user_sessions/new}
    end

    context "with general email suppression enabled" do
      before do
        allow_any_instance_of(described_class).to receive(:suppress_all_emails?).and_return true
      end

      it "is not affected by email suppression enabled" do
        pwd = "password"
        mail = described_class.send_invite user, pwd
        expect(mail.subject).to eq "[VFI Track] Welcome, Joe Schmoe!"
        expect(mail.to).to eq [user.email]

        expect(mail.body.raw_source).to match(/Username: #{user.username}/)
        expect(mail.body.raw_source).to match(/Temporary Password: #{pwd}/)
        expect(mail.body.raw_source).to match %r{user_sessions/new}

        expect(mail.delivery_method).to be_an_instance_of OpenMailer::LoggingMailerProxy
      end
    end
  end

  describe "send_uploaded_items" do
    let(:user) { FactoryBot(:user, first_name: "Joe", last_name: "Schmoe", email: "me@there.com") }

    it "sends imported file data" do
      data = "This is my data, there are many like it but this one is mine."
      imported_file = instance_double("ImportedFile")
      allow(imported_file).to receive(:attached_file_name).and_return "test.txt"
      allow(imported_file).to receive(:module_type).and_return "Product"

      m = described_class.send_uploaded_items "you@there.com", imported_file, data, user
      expect(m.to).to eq ["you@there.com"]
      expect(m.reply_to).to eq [user.email]
      expect(m.subject).to eq "[VFI Track] Product File Result"

      expect(m.attachments["test.txt"]).not_to be_nil
      expect(m.attachments["test.txt"].read).to eq data
    end

    it "does not add attachment if data is too large" do
      data = "This is my data, there are many like it but this one is mine."
      imported_file = instance_double("ImportedFile")
      allow(imported_file).to receive(:attached_file_name).and_return "test.txt"
      allow(imported_file).to receive(:module_type).and_return "Product"

      expect_any_instance_of(described_class).to receive(:save_large_attachment).and_return true

      m = described_class.send_uploaded_items "you@there.com", imported_file, data, user
      expect(m.attachments["test.txt"]).to be_nil
    end
  end

  describe "send_survey_invite" do
    let(:user) { FactoryBot(:user, first_name: "Joe", last_name: "Schmoe", email: "me@there.com") }
    let(:survey) { FactoryBot(:survey) }
    let(:survey_response) { survey.survey_responses.create! user: user, subtitle: "test subtitle" }

    before do
      survey.email_subject = "test subject"
      survey.email_body = "test body"
    end

    context 'with a non-blank subtitle' do
      it "appends a line including the label to the body of the email and the subject" do
        m = described_class.send_survey_invite(survey_response)
        expect(m.body.raw_source).to match(/To view the survey labeled &#39;test subtitle,&#39; follow this link:/)
        expect(m.body.raw_source).to match(%r{https://.*/survey_responses/#{survey_response.id}})
      end
    end

    context 'with a blank subtitle' do
      it "does not add a blank subtitle line to the normal body or subject" do
        survey_response.update! subtitle: ""
        m = described_class.send_survey_invite(survey_response)
        expect(m.subject).to eq "test subject"
        expect(m.body.raw_source).to match(/To view the survey, follow this link:/)
      end
    end

    context 'with user group' do
      let(:group) { FactoryBot(:group) }
      let(:user1) { FactoryBot(:user) }
      let(:user2) { FactoryBot(:user) }

      before do
        user1.groups << group
        user2.groups << group
        survey_response.group = group
      end

      it "splits out user groups emails" do
        described_class.send_survey_invite(survey_response).deliver_now
        m = ActionMailer::Base.deliveries.pop
        expect(m.to).to include user.email
        expect(m.to).to include user1.email
        expect(m.to).to include user2.email

        expect(m.header["X-ORIGINAL-GROUP-TO"].value).to eq group.system_code
      end
    end
  end

  describe "send_survey_reminder" do
    let! (:master_setup) { stub_master_setup }

    it "sends email with specified recipients, subject & body, with a link to the survey" do
      sr = FactoryBot(:survey_response)

      email_to = ["john.smith@abc.com", "sue.anderson@cbs.com"]
      email_subject = "don't forget to complete your survey"
      email_body = "behold, a survey you almost forgot to complete!"
      link_addr = "https://localhost:3000/survey_responses/#{sr.id}"

      described_class.send_survey_reminder(sr, email_to, email_subject, email_body).deliver_now
      m = ActionMailer::Base.deliveries.pop

      expect(m.to).to eq email_to
      expect(m.subject).to eq email_subject
      expect(m.body.raw_source).to match(/#{Regexp.quote(email_body)}.+#{Regexp.quote(link_addr)}/)
    end

  end

  describe "send_search_result_manually" do
    let(:user) { FactoryBot(:user, email: "me@here.com") }

    it "sends email with to, reply_to, subject, body, and attachment" do
       Tempfile.open(["file", "txt"]) do |f|
        f.binmode
        f << "Content"

        expect_any_instance_of(described_class).to receive(:blank_attachment?).and_return false
        described_class.send_search_result_manually("you@there.com", "Subject", "<p>Body</p>", f.path, user).deliver_now

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
      srch = FactoryBot(:search_setup, name: "srch name")
      described_class.send_search_bad_email("tufnel@stonehenge.biz", srch, "Your search has an invalid email!").deliver_now
      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ["tufnel@stonehenge.biz"]
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
      allow_any_instance_of(described_class).to receive(:blank_attachment?).and_return false

      Tempfile.open(['tempfile_a', '.txt']) do |file1|
        Tempfile.open(['tempfile_b', '.txt']) do |file2|
          described_class.send_simple_html(to, sub, body, [file1, file2]).deliver_now
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
      described_class.send_simple_html("me@there.com", "Subject", "This is a test").deliver_now
      email = SentEmail.where(email_subject: "Subject").first
      expect(email.email_body).to include "This is a test"
      expect(email.email_body).to include '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">'
    end

    it "saves data from text emails" do
      described_class.send_simple_text("me@there.com", "Subject", "This is a test").deliver_now
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
      mail = described_class.send_simple_text("me@there.com", "Subject", "Body").deliver_now
      delivery_method = mail.delivery_method
      expect(delivery_method).to be_a OpenMailer::LoggingMailerProxy
      expect(delivery_method.original_delivery_method).not_to be_nil
      expect(delivery_method.sent_email).not_to be_nil
      expect(delivery_method.sent_email.persisted?).to eq true
      expect(delivery_method.settings).not_to be_nil
    end
  end

  describe OpenMailer::LoggingMailerProxy do

    let (:mail) do
      instance_double(Mail::Message)
    end

    let (:original_delivery_method) do
      d = instance_double("DeliveryMethod")
      allow(d).to receive(:deliver!).with(mail).and_return "Delivered"
      d
    end

    let (:sent_email) do
      SentEmail.new
    end

    let (:original_config) do
      {config: "config"}
    end

    let (:settings) do
      c = original_config.dup
      c[:original_delivery_method] = original_delivery_method
      c[:sent_email] = sent_email
      c
    end

    let (:api_error) do
      Postmark::ApiInputError.new
    end

    describe "intialize" do
      it "extracts settings values" do
        p = described_class.new settings
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
        expect(subject.deliver!(mail)).to eq "Delivered"
      end

      it "logs any error messages raised against the sent_email" do
        expect(original_delivery_method).to receive(:deliver!).and_raise "Testing Error"

        expect { subject.deliver! mail }.to raise_error "Testing Error"
        expect(sent_email).to be_persisted
        expect(sent_email.delivery_error).to eq "Testing Error"
      end

      it "swallows Postmark::InvalidMessageError" do
        expect(original_delivery_method).to receive(:deliver!).and_raise api_error
        expect(subject.deliver!(mail)).to be_nil
        expect(sent_email).to be_persisted
        expect(sent_email.delivery_error).to eq "The Postmark API responded with HTTP status 422."
      end
    end
  end
end

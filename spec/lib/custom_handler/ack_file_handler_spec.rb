describe OpenChain::CustomHandler::AckFileHandler do

  let! (:inbound_file) {
    f = InboundFile.new
    f.file_name = "file.csv"
    allow_any_instance_of(described_class).to receive(:inbound_file).and_return f
    f
  }

  context "process_ack_file" do
    let! (:product) { Factory(:product) }

    context "line_handling" do
      it "should not handle error if there isn't one" do
        file_content = "h,h,h\n#{product.unique_identifier},201306191706,OK"
        product.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
        expect(subject).to_not receive(:handle_errors)
        subject.process_ack_file file_content, 'OTHER', "testuser"
      end

      it "should handle multiple errors" do
        file_content = "h,h,h\n#{product.unique_identifier},201306191706,Error 1\n#{product.unique_identifier},201306191706,Error 2"
        product.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
        expect(subject).to receive(:handle_errors).with(["Product #{product.unique_identifier} failed: Error 1", "Product #{product.unique_identifier} failed: Error 2"], "testuser", nil, 'file.csv', file_content, "OTHER")
        subject.process_ack_file file_content, 'OTHER', "testuser"
      end

      it "should take optional separator" do
        file_content = "h|h|h\n#{product.unique_identifier}|201306191706|Problem detail goes here"
        product.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
        expect(subject).to receive(:handle_errors).with(["Product #{product.unique_identifier} failed: Problem detail goes here"], "testuser", nil, 'file.csv', file_content, "OTHER")
        subject.process_ack_file file_content, 'OTHER', "testuser", {csv_opts:{col_sep:'|'}}
      end

      it "should handle extra whitespace" do
        file_content = "h,h,h\n#{product.unique_identifier},201306191706,\"This is some info about the error\"        "
        product.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
        expect(subject).to receive(:handle_errors).with(["Product #{product.unique_identifier} failed: This is some info about the error"], "testuser", nil, 'file.csv', file_content, "OTHER")
        subject.process_ack_file file_content, 'OTHER', "testuser"
      end

      it "should error if file line is too short" do
        # Line has just 2 values.
        bad_line = "#{product.unique_identifier},201306191706"
        file_content = "h,h,h\n#{bad_line}"
        msg = "Malformed response line: #{bad_line}"
        expect(subject).to receive(:handle_errors).with([msg], "testuser", nil, 'file.csv', file_content, "OTHER")
        subject.process_ack_file file_content, 'OTHER', "testuser"
      end

      it "should use error description when provided in (optional) column D" do
        line = "#{product.unique_identifier},201306191706,Would be in errors if next column didn't have value,Include me instead"
        file_content = "h,h,h,h\n#{line}"
        product.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
        expect(subject).to receive(:handle_errors).with(["Product #{product.unique_identifier} failed: Include me instead"], "testuser", nil, 'file.csv', file_content, "OTHER")
        subject.process_ack_file file_content, 'OTHER', "testuser"
      end

      it "should not error if file line is too long" do
        # Line has 5 values: this is OK.
        bad_line = "#{product.unique_identifier},201306191706,3,4,5"
        file_content = "h,h,h\n#{bad_line}"
        product.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
        expect(subject).to receive(:handle_errors).with(["Product #{product.unique_identifier} failed: 4"], "testuser", nil, 'file.csv', file_content, "OTHER")
        subject.process_ack_file file_content, 'OTHER', "testuser"
      end

      it "should ignore a blank error description" do
        line = "#{product.unique_identifier},201306191706,This is the error text to use,   "
        file_content = "h,h,h,h\n#{line}"
        product.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
        expect(subject).to receive(:handle_errors).with(["Product #{product.unique_identifier} failed: This is the error text to use"], "testuser", nil, 'file.csv', file_content, "OTHER")
        subject.process_ack_file file_content, 'OTHER', "testuser"
      end
    end

    context "module_type" do
      it "should default to product handling" do
        sr = product.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
        subject.process_ack_file "h,h,h\n#{product.unique_identifier},201306191706,\"OK\"", 'OTHER', "testuser"
        sr.reload
        expect(sr.confirmed_at).not_to be_nil
      end
      it "should allow alternate module type" do
        ent = Factory(:entry,broker_reference:'123456')
        sr = ent.sync_records.create!(sent_at:1.hour.ago,trading_partner:'OTHER')
        subject.process_ack_file "h,h,h\n123456,201306191706,\"OK\"", 'OTHER', nil, {module_type:'Entry'}
        sr.reload
        expect(sr.confirmed_at).not_to be_nil
      end
    end

    context "sync_records" do
      let! (:user) { Factory(:user, email: "example@example.com", username: "testuser") }

      it "should update product sync record" do
        product.sync_records.create!(:trading_partner=>'XYZ')
        subject.process_ack_file "h,h,h\n#{product.unique_identifier},201306191706,OK", 'XYZ', "testuser"
        product.reload
        expect(product.sync_records.size).to eq(1)
        sr = product.sync_records.first
        expect(sr.trading_partner).to eq('XYZ')
        expect(sr.confirmed_at).to be > 1.minute.ago
        expect(sr.confirmation_file_name).to eq('file.csv')
        expect(sr.failure_message).to be_blank
      end

      it "should not update sync record for another trading partner" do
        product.sync_records.create!(:trading_partner=>'XYZ')
        subject.process_ack_file "h,h,h\n#{product.unique_identifier},201306191706,OK", 'OTHER', "testuser"
        product.reload
        expect(product.sync_records.size).to eq(1)
        sr = product.sync_records.first
        expect(sr.trading_partner).to eq('XYZ')
        expect(sr.confirmed_at).to be_nil
      end
      it "should call errors callback if there is an error" do
        msg = "Product #{product.unique_identifier} confirmed, but it was never sent."
        expect(subject).to receive(:handle_errors).with([msg], "testuser", nil, 'file.csv', "h,h,h\n#{product.unique_identifier},201306191706,OK", "OTHER")
        subject.process_ack_file "h,h,h\n#{product.unique_identifier},201306191706,OK", 'OTHER', "testuser"
      end
    end
  end

  describe "parse" do
    subject { described_class }
    let (:product) { Factory(:product) }
    let! (:user) { Factory(:user, email: "example@example.com", username: "testuser") }

    it "should parse a file" do
      product.sync_records.create!(:trading_partner=>'XYZ')
      subject.parse "h,h,h\n#{product.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv", :sync_code=>"XYZ", email_address: "example@example.com"}
      product.reload
      expect(product.sync_records.size).to eq(1)
      sr = product.sync_records.first
      expect(sr.confirmation_file_name).to eq('file.csv')
    end

    it "should send an email to the user provided if there's an error while processing the file" do
      user = Factory(:user, email: "me@there.com")
      subject.parse("some\ntext",{key:"fake-bucket/fake-file.txt", sync_code: "XYZ", username: user.username})

      expect(OpenMailer.deliveries.last.to.first).to eq(user.email)
      expect(OpenMailer.deliveries.last.subject).to eq("[VFI Track] Ack File Processing Error")
    end

    it "should send an email to multiple users if there's an error while processing the file" do
      me = Factory(:user, email: "me@there.com")
      you = Factory(:user, email: "you@there.com")
      subject.parse("some\ntext",{key:"fake-bucket/fake-file.txt", sync_code: "XYZ", username: [me.username, you.username]})

      expect((OpenMailer.deliveries.last.to - [me.email, you.email]).size).to eq(0)
      expect(OpenMailer.deliveries.last.subject).to eq("[VFI Track] Ack File Processing Error")
    end

    it "should send an email to the user provided if there's an error while processing the file" do
      user = Factory(:user, email: "me@there.com")
      subject.parse("some\ntext",{key:"fake-bucket/fake-file.txt", sync_code: "XYZ", username: user.username})

      expect(OpenMailer.deliveries.last.to.first).to eq(user.email)
      expect(OpenMailer.deliveries.last.subject).to eq("[VFI Track] Ack File Processing Error")
    end

    it "should send an email to the MailingList provided if there's an error while processing the file" do
      list = Factory(:mailing_list, system_code: "list", email_addresses: "me@there.com")
      subject.parse("some\ntext",{key:"fake-bucket/fake-file.txt", sync_code: "XYZ", mailing_list_code: "list"})

      expect(OpenMailer.deliveries.last.to.first).to eq("me@there.com")
      expect(OpenMailer.deliveries.last.subject).to eq("[VFI Track] Ack File Processing Error")
    end

    it "should send an email to mailing list and user if there's an error while processing the file" do
      user = Factory(:user, email: "me@there.com")
      list = Factory(:mailing_list, system_code: "list", email_addresses: "you@there.com", user: user, company: user.company)
      
      subject.parse("some\ntext",{key:"fake-bucket/fake-file.txt", sync_code: "XYZ", username: user.username, mailing_list_code: "list"})

      expect(OpenMailer.deliveries.last.to).to eq(["me@there.com", "you@there.com"])
      expect(OpenMailer.deliveries.last.subject).to eq("[VFI Track] Ack File Processing Error")
    end

    it "should send an email to to support if there's an error while processing the file and no user or list is setup" do
      subject.parse("some\ntext",{key:"fake-bucket/fake-file.txt", sync_code: "XYZ"})

      expect(OpenMailer.deliveries.last.to).to eq(["support@vandegriftinc.com"])
      expect(OpenMailer.deliveries.last.subject).to eq("[VFI Track] Ack File Processing Error")
    end

    it "should error if key is missing" do
      expect{subject.parse "h,h,h\n#{product.unique_identifier},201306191706,OK", {:sync_code=>"XYZ", email_address: "example@example.com"}}.to raise_error ArgumentError, "Opts must have an s3 :key hash key."
    end

    it "should error if sync_code is missing" do
      expect{subject.parse "h,h,h\n#{product.unique_identifier},201306191706,OK", {:key=>"/path/to/file.csv", email_address: "example@example.com"}}.to raise_error ArgumentError, "Opts must have a :sync_code hash key."
    end

  end
end

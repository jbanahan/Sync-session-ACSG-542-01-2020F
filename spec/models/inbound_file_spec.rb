describe InboundFile do

  describe "user permission functions" do
    let(:user) { Factory(:user) }

    describe "find_can_view" do
      let!(:file) { InboundFile.create }

      it "shows all records to sys-admins" do
        expect(user).to receive(:sys_admin?).and_return true
        expect(described_class.find_can_view(user).count).to eq 1
      end

      it "shows nothing to non sys-admins" do
        expect(user).to receive(:sys_admin?).and_return false
        expect(described_class.find_can_view(user)).to be_nil
      end
    end

    describe "can_view?" do
      it "grants access to to sys-admins" do
        expect(user).to receive(:sys_admin?).and_return true
        expect(subject.can_view?(user)).to eq true
      end

      it "forbids access to non sys-admins" do
        expect(user).to receive(:sys_admin?).and_return false
        expect(subject.can_view?(user)).to eq false
      end
    end
  end

  # This also tests add_info_message, add_warning_message, add_reject_message and add_error_message.
  describe "get_process_status_from_messages" do
    it "calculates process status from log with only info messages" do
      inf = InboundFile.new
      inf.add_info_message "Test"
      inf.add_info_message "Test 2"
      inf.add_info_message "Test 3"
      expect(inf.get_process_status_from_messages).to eq InboundFile::PROCESS_STATUS_SUCCESS
    end

    it "calculates process status from log with warning message" do
      inf = InboundFile.new
      inf.add_info_message "Test"
      inf.add_warning_message "Test 2"
      inf.add_info_message "Test 3"
      expect(inf.get_process_status_from_messages).to eq InboundFile::PROCESS_STATUS_WARNING
    end

    it "calculates process status from log with reject message" do
      inf = InboundFile.new
      inf.add_info_message "Test"
      inf.add_reject_message "Test 2"
      inf.add_warning_message "Test 3"
      expect(inf.get_process_status_from_messages).to eq InboundFile::PROCESS_STATUS_REJECT
    end

    it "calculates process status from log with error message" do
      inf = InboundFile.new
      inf.add_reject_message "Test"
      inf.add_error_message "Test 2"
      inf.add_warning_message "Test 3"
      expect(inf.get_process_status_from_messages).to eq InboundFile::PROCESS_STATUS_ERROR
    end
  end

  describe "add_message" do
    it "tests basic message-adding functionality" do
      inf = InboundFile.new
      inf.add_message InboundFileMessage::MESSAGE_STATUS_INFO, "A"
      inf.add_message InboundFileMessage::MESSAGE_STATUS_WARNING, "B"
      inf.add_message InboundFileMessage::MESSAGE_STATUS_REJECT, "C"
      inf.add_message InboundFileMessage::MESSAGE_STATUS_ERROR, "D"
      expect(inf.messages.length).to eq(4)
      expect(inf.messages[0].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_INFO)
      expect(inf.messages[0].message).to eq("A")
      expect(inf.messages[1].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_WARNING)
      expect(inf.messages[1].message).to eq("B")
      expect(inf.messages[2].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_REJECT)
      expect(inf.messages[2].message).to eq("C")
      expect(inf.messages[3].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_ERROR)
      expect(inf.messages[3].message).to eq("D")
    end

    it "handles bogus message status" do
      inf = InboundFile.new
      begin
        inf.add_message "Nope!", "A"
        fail "Should have thrown exception"
      rescue ArgumentError => e
        expect(e.to_s).to eq("Invalid message status: Nope!")
      end
      expect(inf.messages.length).to eq(0)
    end
  end

  describe "reject_and_raise" do
    it "logs a reject message and raises an exception" do
      inf = InboundFile.new
      begin
        inf.reject_and_raise "Failed some rule"
        fail "Should have thrown exception"
      rescue LoggedParserRejectionError => e
        expect(e.to_s).to eq("Failed some rule")
      end
      expect(inf.messages.length).to eq(1)
      expect(inf.messages[0].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_REJECT)
      expect(inf.messages[0].message).to eq("Failed some rule")
    end

    it "logs a reject message and raises a typed exception" do
      inf = InboundFile.new
      begin
        inf.reject_and_raise "Failed some rule", error_class:ArgumentError
        fail "Should have thrown exception"
      rescue ArgumentError => e
        expect(e.to_s).to eq("Failed some rule")
      end
      expect(inf.messages.length).to eq(1)
      expect(inf.messages[0].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_REJECT)
      expect(inf.messages[0].message).to eq("Failed some rule")
    end
  end

  describe "error_and_raise" do
    it "logs an error message and raises an exception" do
      inf = InboundFile.new
      begin
        inf.error_and_raise "Something bad happened"
        fail "Should have thrown exception"
      rescue LoggedParserFatalError  => e
        expect(e.to_s).to eq("Something bad happened")
      end
      expect(inf.messages.length).to eq(1)
      expect(inf.messages[0].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_ERROR)
      expect(inf.messages[0].message).to eq("Something bad happened")
    end

    it "logs an error message and raises a typed exception" do
      inf = InboundFile.new
      begin
        inf.error_and_raise "Something bad happened", error_class:ArgumentError
        fail "Should have thrown exception"
      rescue ArgumentError => e
        expect(e.to_s).to eq("Something bad happened")
      end
      expect(inf.messages.length).to eq(1)
      expect(inf.messages[0].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_ERROR)
      expect(inf.messages[0].message).to eq("Something bad happened")
    end
  end

  describe "remove_dupe_messages" do
    it "removes dupe messages from object but preserves initial order" do
      inf = InboundFile.new
      inf.add_info_message "B"
      inf.add_warning_message "B"
      inf.add_info_message "A"
      inf.add_info_message "B"
      inf.add_info_message "C"
      inf.add_reject_message "A"
      inf.add_info_message "A"

      inf.remove_dupe_messages

      # 7 enter, 5 leave.  The remaining items should not have been sorted alphabetically and/or by type.
      expect(inf.messages.length).to eq 5

      expect(inf.messages[0].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_INFO)
      expect(inf.messages[0].message).to eq("B")
      expect(inf.messages[1].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_WARNING)
      expect(inf.messages[1].message).to eq("B")
      expect(inf.messages[2].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_INFO)
      expect(inf.messages[2].message).to eq("A")
      expect(inf.messages[3].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_INFO)
      expect(inf.messages[3].message).to eq("C")
      expect(inf.messages[4].message_status).to eq(InboundFileMessage::MESSAGE_STATUS_REJECT)
      expect(inf.messages[4].message).to eq("A")
    end
  end

  describe "get_messages_by_status" do
    it "finds messages with a specific status" do
      inf = InboundFile.new
      inf.add_warning_message "A"
      inf.add_warning_message "B"
      inf.add_reject_message "C"
      inf.add_reject_message "D"

      arr = inf.get_messages_by_status InboundFileMessage::MESSAGE_STATUS_REJECT
      expect(arr.length).to eq 2
      expect(arr[0].message).to eq "C"
      expect(arr[1].message).to eq "D"
      arr = inf.get_messages_by_status InboundFileMessage::MESSAGE_STATUS_WARNING
      expect(arr.length).to eq 2
      expect(arr[0].message).to eq "A"
      expect(arr[1].message).to eq "B"
      expect(inf.get_messages_by_status InboundFileMessage::MESSAGE_STATUS_ERROR).to eq []
      expect(inf.get_messages_by_status nil).to eq []
    end
  end

  describe "add_identifier" do
    it "tests basic identifier-adding functionality" do
      inf = InboundFile.new
      inf.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, "ABC123", module_type:"Order", module_id:123
      # This one should be ignored because it's a dupe.
      inf.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, "ABC123"
      inf.add_identifier InboundFileIdentifier::TYPE_ARTICLE_NUMBER, "555222", module_type:"Product", module_id:456
      inf.add_identifier "Something With No Module", "whee"

      expect(inf.identifiers.length).to eq 3
      expect(inf.identifiers[0].identifier_type).to eq(InboundFileIdentifier::TYPE_PO_NUMBER)
      expect(inf.identifiers[0].value).to eq("ABC123")
      expect(inf.identifiers[0].module_type).to eq("Order")
      expect(inf.identifiers[0].module_id).to eq(123)

      expect(inf.identifiers[1].identifier_type).to eq(InboundFileIdentifier::TYPE_ARTICLE_NUMBER)
      expect(inf.identifiers[1].value).to eq("555222")
      expect(inf.identifiers[1].module_type).to eq("Product")
      expect(inf.identifiers[1].module_id).to eq(456)

      expect(inf.identifiers[2].identifier_type).to eq("Something With No Module")
      expect(inf.identifiers[2].value).to eq("whee")
      expect(inf.identifiers[2].module_type).to be_nil
      expect(inf.identifiers[2].module_id).to be_nil
    end

    it "handles symbolized identifier types" do
      subject.add_identifier :po_number, "123"

      expect(subject.identifiers[0].identifier_type).to eq InboundFileIdentifier::TYPE_PO_NUMBER
    end

    it "handles bogus module type" do
      inf = InboundFile.new
      begin
        inf.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, "ABC123", module_type:"BOGUS", module_id:123
        fail "Should have thrown exception"
      rescue ArgumentError => e
        expect(e.to_s).to eq("Invalid module type: BOGUS")
      end
      expect(inf.identifiers.length).to eq 0
    end
  end

  describe "set_identifier_module_info" do
    it "sets module info for matching identifier" do
      inf = InboundFile.new
      inf.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, "ABC123"
      inf.add_identifier InboundFileIdentifier::TYPE_ARTICLE_NUMBER, "555222"
      # It's highly unlikely you'd actually WANT to do this for two POs, since they'd represent two different modules.
      # Merely testing concept/functionality.
      inf.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, "DEF456"

      inf.set_identifier_module_info InboundFileIdentifier::TYPE_PO_NUMBER, "Order", 123

      ident_1 = inf.identifiers[0]
      expect(ident_1.identifier_type).to eq InboundFileIdentifier::TYPE_PO_NUMBER
      expect(ident_1.value).to eq "ABC123"
      expect(ident_1.module_type).to eq "Order"
      expect(ident_1.module_id).to eq 123

      ident_2 = inf.identifiers[1]
      expect(ident_2.identifier_type).to eq InboundFileIdentifier::TYPE_ARTICLE_NUMBER
      expect(ident_2.value).to eq "555222"
      expect(ident_2.module_type).to be_nil
      expect(ident_2.module_id).to be_nil

      ident_3 = inf.identifiers[2]
      expect(ident_3.identifier_type).to eq InboundFileIdentifier::TYPE_PO_NUMBER
      expect(ident_3.value).to eq "DEF456"
      expect(ident_3.module_type).to eq "Order"
      expect(ident_3.module_id).to eq 123

      inf.set_identifier_module_info InboundFileIdentifier::TYPE_PO_NUMBER, "Order", 456, value:"ABC123"
      expect(ident_1.module_id).to eq 456
      # Should not have been updated because value doesn't match.
      expect(ident_3.module_id).to eq 123
    end

    it "does nothing if matching identifier can't be found" do
      inf = InboundFile.new

      inf.set_identifier_module_info InboundFileIdentifier::TYPE_PO_NUMBER, "Order", 123

      expect(inf.identifiers.length).to eq 0
    end

    it "handles bogus module type" do
      inf = InboundFile.new
      begin
        inf.set_identifier_module_info InboundFileIdentifier::TYPE_PO_NUMBER, "BOGUS", 123
        fail "Should have thrown exception"
      rescue ArgumentError => e
        expect(e.to_s).to eq("Invalid module type: BOGUS")
      end
      expect(inf.identifiers.length).to eq 0
    end
  end

  describe "get_identifiers" do
    let(:inf) {
      inf = InboundFile.new
      inf.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, "ABC123"
      inf.add_identifier InboundFileIdentifier::TYPE_ARTICLE_NUMBER, "555222"
      inf.add_identifier InboundFileIdentifier::TYPE_PO_NUMBER, "DEF456"
      inf
    }

    it "finds identifiers with a specific type" do
      arr = inf.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER)
      expect(arr.length).to eq 2
      expect(arr[0].value).to eq "ABC123"
      expect(arr[1].value).to eq "DEF456"

      expect(inf.get_identifiers(InboundFileIdentifier::TYPE_ARTICLE_NUMBER)[0].value).to eq "555222"
      expect(inf.get_identifiers("Unknowable Type").length).to eq 0
      expect(inf.get_identifiers(nil).length).to eq 0
    end

    it "finds identifiers with a specific type and value" do
      expect(inf.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER, value:"ABC123").length).to eq 1
      expect(inf.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER, value:"DEF456").length).to eq 1
      expect(inf.get_identifiers(InboundFileIdentifier::TYPE_PO_NUMBER, value:"555222").length).to eq 0
      expect(inf.get_identifiers(InboundFileIdentifier::TYPE_ARTICLE_NUMBER, value:"555222").length).to eq 1
    end

    it "handles symbolized identifier types" do
      expect(inf.get_identifiers(:po_number).length).to eq 2
    end
  end

  describe "purge" do
    it "purges InboundFiles created before a specific date" do
      inf = InboundFile.new
      inf.add_info_message "Nearly departed"
      inf.add_identifier "Something With No Module", "whee"

      Timecop.freeze(Date.new(2017,7,7)) do
        inf.save!
        expect(inf.created_at).to eq(Date.new(2017,7,7))
      end

      described_class.purge Date.new(2017,10,10)
      expect(InboundFile.where(id:inf.id).length).to eq 0
    end
  end

  describe "failed?" do

    it "returns false by default" do
      expect(subject.failed?).to eq false
    end

    context "with overall status set" do 
      it "returns true if overall status is error" do
        subject.process_status = InboundFile::PROCESS_STATUS_ERROR
        expect(subject.failed?).to eq true
      end

      it "returns true if overall status is reject" do
        subject.process_status = InboundFile::PROCESS_STATUS_REJECT
        expect(subject.failed?).to eq true
      end

      it "returns false if overall status is warning" do
        subject.process_status = InboundFile::PROCESS_STATUS_WARNING
        expect(subject.failed?).to eq false
      end

      it "returns false if overall status is success" do
        subject.process_status = InboundFile::PROCESS_STATUS_SUCCESS
        expect(subject.failed?).to eq false
      end

      it "returns false if overall status is pending" do
        subject.process_status = InboundFile::PROCESS_STATUS_PENDING
        expect(subject.failed?).to eq false
      end
    end

    context "with pending status" do
      it "returns true if error message is present" do
        subject.add_error_message "E"
        expect(subject.failed?).to eq true
      end

      it "returns true if reject message is present" do
        subject.add_reject_message "E"
        expect(subject.failed?).to eq true
      end

      it "returns false if warning message is present" do
        subject.add_warning_message "E"
        expect(subject.failed?).to eq false
      end

      it "returns false if info message is present" do
        subject.add_info_message "E"
        expect(subject.failed?).to eq false
      end
    end
  end

end
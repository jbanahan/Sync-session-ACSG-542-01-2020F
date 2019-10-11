describe OpenChain::CustomHandler::FootLocker::FootLockerEntry810Comparator do

  describe "accept?" do
    subject { described_class }

    let (:entry) {
      e = Entry.new source_system: Entry::KEWILL_SOURCE_SYSTEM, customer_number: "FOOLO", file_logged_date: Date.new(2019, 1, 7), entry_filed_date: Date.new(2018, 5, 1), arrival_date: Date.new(2018, 5, 2), release_date: Date.new(2018, 5, 3)
      e.broker_invoices.build invoice_number: "123", invoice_date: Date.new(2018, 4, 1)
      e
    }

    let (:snapshot) {
      EntitySnapshot.new recordable: entry
    }

    context "with accepted data" do
      after :each do 
        expect(subject.accept? snapshot).to eq true
      end
      
      it "accepts FOOLO entries that have been logged and have invoices" do
        
      end

      it "accepts FOOCA entries that have been logged and have invoices" do
        entry.customer_number = 'FOOCA'
      end

      it "accepts TEAED entries that have been logged and have invoices" do
        entry.customer_number = 'TEAED'
      end

      it "accepts FOOTLOCKE entries that have been logged and have invoices" do
        entry.customer_number = 'FOOTLOCKE'
        # This field isn't checked for this customer number.
        entry.arrival_date = nil
        # These also come from a different system.
        entry.source_system = Entry::FENIX_SOURCE_SYSTEM
      end

      it "accepts FOOT LOCKER CANADA C entries that have been logged and have invoices" do
        entry.customer_number = 'FOOT LOCKER CANADA C'
        # This field isn't checked for this customer number.
        entry.arrival_date = nil
        # These also come from a different system.
        entry.source_system = Entry::FENIX_SOURCE_SYSTEM
      end
    end
    
    context "with unaccepted data" do
      after :each do 
        expect(subject.accept? snapshot).to eq false
      end

      it "does not accept entries for non-Footlocker customer numbers" do
        entry.customer_number = "NONFOOLO"
      end

      it "does not accept entries that don't have invoices" do
        entry.broker_invoices.clear
      end

      it "does not accept entries that have not been logged" do
        entry.file_logged_date = nil
      end

      it "does not accept entries that have been logged prior to Jan 1, 2019" do
        entry.file_logged_date = Date.new(2018, 12, 31)
      end

      it "does not accept entries without an entry filed date" do
        entry.entry_filed_date = nil
      end

      it "does not accept entries without a release date" do
        entry.release_date = nil
      end

      it "does not accept entries without an arrival date" do
        entry.arrival_date = nil
      end
    end
  end

  describe "compare" do
    subject { described_class }

    let (:entry) { 
      e = Factory(:entry) 
      e.broker_invoices << Factory(:broker_invoice, entry: e)
      e
    }

    it "calls generate and send if any broker invoices have not been synced" do
      expect_any_instance_of(described_class).to receive(:generate_and_send).with(entry)

      subject.compare nil, entry.id, nil, nil, nil, nil, nil, nil
    end

    it "doesn't call generate and send if all broker invoices have been synced" do
      entry.broker_invoices.first.sync_records.create! trading_partner: "FOOLO 810", sent_at: Time.zone.now
      expect_any_instance_of(described_class).not_to receive(:generate_and_send)
      
      subject.compare nil, entry.id, nil, nil, nil, nil, nil, nil
    end
  end

  describe "generate_and_send" do
    let (:entry) { 
      e = Factory(:entry, customer_number:'FOOLO')
      e.broker_invoices << Factory(:broker_invoice, entry: e)
      e
    }

    let (:xml_generator) {
      instance_double(OpenChain::CustomHandler::FootLocker::FootLocker810Generator)
    }

    it "generates xml for each invoice and sends it" do
      broker_invoice = entry.broker_invoices.first

      expect(subject).to receive(:xml_generator).and_return xml_generator
      expect(xml_generator).to receive(:generate_xml).with(broker_invoice).and_return REXML::Document.new("<test/>")
      expect(subject).to receive(:ftp_sync_file) do |file, sync_record, props|
        expect(file).to be_a(Tempfile)
        expect(file.read).to eq "<test/>"
        expect(sync_record).to be_a(SyncRecord)
        expect(props[:folder]).to eq "to_ecs/footlocker_810"
      end

      subject.generate_and_send entry

      broker_invoice.reload

      sr = broker_invoice.sync_records.first
      expect(sr).not_to be_nil
      expect(sr.trading_partner).to eq "FOOLO 810"
      expect(sr.sent_at).to be_within(1.minute).of(Time.zone.now)
      expect(sr.confirmed_at).to be_within(2.minutes).of(Time.zone.now)
    end

    describe "Canada" do
      it "generates Canada xml for each invoice and sends it (FOOTLOCKE)" do
        entry.customer_number = 'FOOTLOCKE'
      end

      it "generates Canada xml for each invoice and sends it (FOOT LOCKER CANADA C)" do
        entry.customer_number = 'FOOT LOCKER CANADA C'
      end

      after :each do
        broker_invoice = entry.broker_invoices.first

        expect(subject).to receive(:xml_generator).and_return xml_generator
        expect(xml_generator).to receive(:generate_xml).with(broker_invoice).and_return REXML::Document.new("<test/>")
        expect(subject).to receive(:ftp_sync_file) do |file, sync_record, props|
          expect(file).to be_a(Tempfile)
          expect(file.read).to eq "<test/>"
          expect(sync_record).to be_a(SyncRecord)
          # Different folder.
          expect(props[:folder]).to eq "to_ecs/footlocker_810_CA"
        end

        subject.generate_and_send entry

        broker_invoice.reload

        sr = broker_invoice.sync_records.first
        expect(sr).not_to be_nil
        expect(sr.trading_partner).to eq "FOOLO 810"
        expect(sr.sent_at).to be_within(1.minute).of(Time.zone.now)
        expect(sr.confirmed_at).to be_within(2.minutes).of(Time.zone.now)
      end
    end

  end
end
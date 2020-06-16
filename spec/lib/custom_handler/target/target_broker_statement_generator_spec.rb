describe OpenChain::CustomHandler::Target::TargetDailyBrokerStatementGenerator do
  describe "generate_and_send" do
    it "generates and sends a file" do
      target = with_customs_management_id(Factory(:importer), "TARGEN")

      stmt_1 = Factory(:daily_statement, statement_number: "ST_1", status: "F", final_received_date: Date.new(2020, 3, 23), importer_id: target.id)
      stmt_1.daily_statement_entries.create(entry: Factory(:entry, entry_number: "1234567890123"), total_amount: BigDecimal("123.45"))
      stmt_1.daily_statement_entries.create(entry: Factory(:entry, entry_number: "2345678901234"), total_amount: BigDecimal("12.34"))

      # This one has a sync record, but it has no sent at date.  It should be included on the report.
      stmt_2 = Factory(:daily_statement, statement_number: "ST_2", status: "F", final_received_date: Date.new(2020, 3, 20), importer_id: target.id)
      stmt_2.daily_statement_entries.create(entry: Factory(:entry, entry_number: "3456789012345"), total_amount: BigDecimal("6789.01"))
      sync_exist = stmt_2.sync_records.create!(trading_partner: described_class::SYNC_TRADING_PARTNER, sent_at: nil)

      # Should not be included because its status is not F
      stmt_not_final = Factory(:daily_statement, statement_number: "ST_3", status: "G", final_received_date: Date.new(2020, 3, 23), importer_id: target.id)
      stmt_not_final.daily_statement_entries.create

      # Should not be included because its final received date occurs on the date provided by Timecop (representing today).
      stmt_today = Factory(:daily_statement, statement_number: "ST_4", status: "F", final_received_date: Date.new(2020, 3, 24), importer_id: target.id)
      stmt_today.daily_statement_entries.create

      # Should not be included because it has been previously sent (existing sync record).
      stmt_prev_sent = Factory(:daily_statement, statement_number: "ST_5", status: "F", final_received_date: Date.new(2020, 3, 23), importer_id: target.id)
      stmt_prev_sent.daily_statement_entries.create
      stmt_prev_sent.sync_records.create!(trading_partner: described_class::SYNC_TRADING_PARTNER, sent_at: Date.new(2020, 3, 11))

      data = nil
      expect(subject).to receive(:ftp_sync_file) do |file, sync_records|
        data = file.read
        sync_records.each do |sync|
          sync.ftp_session_id = 357
        end
        expect(file.original_filename).to eq "BROKER_STMT_2020-03-24.txt"
        file.close!
      end

      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:00")
      Timecop.freeze(current) do
        subject.generate_and_send
      end

      expect(data).to eq "ST_1           20200323123-456789012-3                    000000012345F\n" +
                         "ST_1           20200323234-567890123-4                    000000001234F\n" +
                         "ST_2           20200320345-678901234-5                    000000678901F\n"

      stmt_1.reload
      expect(stmt_1.sync_records.length).to eq 1
      expect(stmt_1.sync_records[0].trading_partner).to eq described_class::SYNC_TRADING_PARTNER
      expect(stmt_1.sync_records[0].sent_at).to eq (current - 1.second)
      expect(stmt_1.sync_records[0].confirmed_at).to eq current
      expect(stmt_1.sync_records[0].ftp_session_id).to eq 357

      stmt_2.reload
      expect(stmt_2.sync_records.length).to eq 1
      expect(stmt_2.sync_records[0].trading_partner).to eq described_class::SYNC_TRADING_PARTNER
      expect(stmt_2.sync_records[0].ftp_session_id).to eq 357
      # Should have reused same sync record.
      expect(stmt_2.sync_records[0].id).to eq sync_exist.id
    end

    it "generates and sends a file with system date limit set" do
      target = with_customs_management_id(Factory(:importer), "TARGEN")
      SystemDate.create!(date_type: described_class::SYNC_TRADING_PARTNER, start_date: Date.new(2020, 3, 21))

      stmt_1 = Factory(:daily_statement, statement_number: "ST_1", status: "F", final_received_date: Date.new(2020, 3, 23), importer_id: target.id)
      stmt_1.daily_statement_entries.create(entry: Factory(:entry, entry_number: "1234567890123"), total_amount: BigDecimal("123.45"))

      # Should not be included because its final received date occurs prior to the system date.
      stmt_2 = Factory(:daily_statement, statement_number: "ST_2", status: "F", final_received_date: Date.new(2020, 3, 20), importer_id: target.id)
      stmt_2.daily_statement_entries.create(entry: Factory(:entry, entry_number: "3456789012345"), total_amount: BigDecimal("6789.01"))

      data = nil
      expect(subject).to receive(:ftp_sync_file) do |file, _sync_records|
        data = file.read
        file.close!
      end

      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:00")
      Timecop.freeze(current) do
        subject.generate_and_send
      end

      expect(data).to eq "ST_1           20200323123-456789012-3                    000000012345F\n"

      stmt_1.reload
      expect(stmt_1.sync_records.length).to eq 1

      stmt_2.reload
      expect(stmt_2.sync_records.length).to eq 0
    end

    it "raises an error if Target isn't found" do
      expect { subject.generate_and_send }.to raise_error "Target company record not found."
    end
  end

  describe "run_schedulable" do
    it "calls generate and send method" do
      expect_any_instance_of(described_class).to receive(:generate_and_send)

      described_class.run_schedulable
    end
  end

  describe "ftp_credentials" do
    it "gets test creds" do
      allow(stub_master_setup).to receive(:production?).and_return false
      cred = subject.ftp_credentials
      expect(cred[:folder]).to eq "to_ecs/target_broker_statement_test"
    end

    it "gets production creds" do
      allow(stub_master_setup).to receive(:production?).and_return true
      cred = subject.ftp_credentials
      expect(cred[:folder]).to eq "to_ecs/target_broker_statement"
    end
  end
end
describe OpenChain::CustomHandler::Ascena::AscenaFtzBillingInvoiceFileGenerator do

  describe "run_schedulable" do
    it "executes #generate_and_send, initializes custom_where" do
      expect_any_instance_of(described_class).to receive(:generate_and_send).with("ASCE") do |generator|
        expect(generator.custom_where).to eq "SOME SQL"
      end
      described_class.run_schedulable("customer_number" => "ASCE", "custom_where" => "SOME SQL")
    end
  end

  describe "generate_and_send" do
    let! (:today) { Time.zone.now.to_date }

    let! (:entry) do
      entry = create(:entry, customer_number: "ASCE", entry_number: "ENTRYNO", entry_type: "06", first_entry_sent_date: today, broker_reference: "REF")
      entry.attachments << create(:attachment, attachment_type: "FTZ Supplemental Data")

      commercial_invoice = create(:commercial_invoice, entry: entry)
      invoice_line1 = create(:commercial_invoice_line, commercial_invoice: commercial_invoice)
      create(:commercial_invoice_tariff, commercial_invoice_line: invoice_line1)

      invoice_line2 = create(:commercial_invoice_line, commercial_invoice: commercial_invoice)
      create(:commercial_invoice_tariff, commercial_invoice_line: invoice_line2)

      # Make two lines for the same PO, so we make sure we're handling the sum'ing at po level correctly as well as the proration for brokerage lines
      invoice_line3 = create(:commercial_invoice_line, commercial_invoice: commercial_invoice)
      create(:commercial_invoice_tariff, commercial_invoice_line: invoice_line3)

      invoice_line4 = create(:commercial_invoice_line, commercial_invoice: commercial_invoice)
      create(:commercial_invoice_tariff, commercial_invoice_line: invoice_line4)

      entry
    end

    let! (:broker_invoice) do
      create(:broker_invoice, entry: entry, invoice_number: "INVOICENUMBER", invoice_date: today)
    end

    let! (:broker_invoice_line_duty) do
      create(:broker_invoice_line, broker_invoice: broker_invoice, charge_code: "0001", charge_amount: 211.00, charge_description: "DUTY")
    end

    # Gets skipped
    let! (:broker_invoice_line_duty_direct) do
      create(:broker_invoice_line, broker_invoice: broker_invoice, charge_code: "0099", charge_amount: 100.00, charge_description: "Duty Paid Direct")
    end

    # Gets skipped
    let! (:broker_invoice_line_brokerage) do
      create(:broker_invoice_line, broker_invoice: broker_invoice, charge_code: "0007", charge_amount: 50.00, charge_description: "Brokerage")
    end

    let! (:user) { create(:master_user) }

    let (:broker_invoice_with_duty_snapshot) do
      broker_invoice_line_duty
      broker_invoice_line_duty_direct
      broker_invoice.reload

      entry.broker_invoices << broker_invoice

      entry.reload
      JSON.parse CoreModule::ENTRY.entity_json(entry)
    end

    let! (:broker_invoice_with_all_charges_snapshot) do
      broker_invoice_line_duty
      broker_invoice_line_duty_direct
      broker_invoice_line_brokerage
      broker_invoice.reload

      entry.broker_invoices << broker_invoice

      entry.reload
      JSON.parse CoreModule::ENTRY.entity_json(entry)
    end

    let (:suppl_file) do
      csv =  ",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,\n" \
             ",,,,,,,5,,,,11,,,,,1,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,21,,,,PO 1,,,,,,,,,,,,,,,,,,,,,,\n" \
             ",,,,,,,35,,,,12,,,,,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,22,,,,PO 2,,,,,,,,,,,,,,,,,,,,,,\n" \
             ",,,,,,,37,,,,13,,,,,3,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,23,,,,PO 3,,,,,,,,,,,,,,,,,,,,,,\n" \
             ",,,,,,,37,,,,14,,,,,4,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,24,,,,PO 3,,,,,,,,,,,,,,,,,,,,,,\n"

      temp = Tempfile.new(["suppl", ".csv"])
      temp << csv
      temp.flush
      temp
    end

    def mock_attachment_download config
      allow_any_instance_of(Attachment).to receive(:download_to_tempfile) do |att, &block|
        block.call config[att.attachable_type]
      end
    end

    before do
      entry.create_snapshot User.integration
      allow_any_instance_of(EntitySnapshot).to receive(:snapshot_json).and_return(broker_invoice_with_all_charges_snapshot)
      mock_attachment_download("Entry" => suppl_file)
    end

    after do
      suppl_file.close
    end

    it "generates an Ascena billing file with only duty data" do
      data = nil
      expect(subject).to receive(:ftp_file) do |file, _opts|
        expect(File.basename(file).split("_").first).to eq "ASC"
        data = file.read
      end

      expect(Lock).to receive(:db_lock).with(entry).and_yield

      subject.generate_and_send "ASCE"

      lines = CSV.parse data, col_sep: "|"

      expect(lines.length).to eq 4

      # The header and lines are intentially not equal as the header value comes directly from the invoice charge line
      # while the line values come from the calculated duty totals on the individual invoice lines
      expect(lines[0]).to eq ["H", "INVOICENUMBER", "STANDARD", today.strftime("%m/%d/%Y"), "00151", "211.0", "USD", "For Customs Entry # ENTRYNO"]
      expect(lines[1]).to eq ["L", "INVOICENUMBER", "1", "00151", "46.42", "Duty", "PO 1", "151"]
      expect(lines[2]).to eq ["L", "INVOICENUMBER", "2", "00151", "50.64", "Duty", "PO 2", "7220"]
      expect(lines[3]).to eq ["L", "INVOICENUMBER", "3", "00151", "113.94", "Duty", "PO 3", "7218"]
    end

    it "overrides sync records with custom_where" do
      generator = described_class.new(custom_where: "broker_invoices.invoice_number = 'INVOICENUMBER'")
      broker_invoice.sync_records.create! trading_partner: "ASCE_DUTY_BILLING", sent_at: 10.minutes.ago, confirmed_at: 5.minutes.ago
      broker_invoice.invoice_date = today - (1.month + 1.day)
      broker_invoice.updated_at = 1.day.ago
      broker_invoice.save!

      data = nil
      expect(generator).to receive(:ftp_file) do |file, _opts|
        expect(File.basename(file).split("_").first).to eq "ASC"
        data = file.read
      end

      expect(Lock).to receive(:db_lock).with(entry).and_yield

      generator.generate_and_send "ASCE"

      lines = CSV.parse data, col_sep: "|"

      expect(lines.length).to eq 4

      expect(lines[0]).to eq ["H", "INVOICENUMBER", "STANDARD", today.strftime("%m/%d/%Y"), "00151", "211.0", "USD", "For Customs Entry # ENTRYNO"]
      expect(lines[1]).to eq ["L", "INVOICENUMBER", "1", "00151", "46.42", "Duty", "PO 1", "151"]
      expect(lines[2]).to eq ["L", "INVOICENUMBER", "2", "00151", "50.64", "Duty", "PO 2", "7220"]
      expect(lines[3]).to eq ["L", "INVOICENUMBER", "3", "00151", "113.94", "Duty", "PO 3", "7218"]
    end

    it "concatenates reports for multiple entries" do
      entry2 = create(:entry, customer_number: "ASCE", entry_number: "ENTRYNO 2", entry_type: "06", first_entry_sent_date: today, broker_reference: "REF 2")
      entry2.create_snapshot User.integration
      entry2.attachments << create(:attachment, attachment_type: "FTZ Supplemental Data")
      ci = create(:commercial_invoice, entry: entry2)
      cil = create(:commercial_invoice_line, commercial_invoice: ci, customs_line_number: 1, prorated_mpf: BigDecimal(10))
      create(:commercial_invoice_tariff, commercial_invoice_line: cil, duty_amount: BigDecimal(20))
      bi = create(:broker_invoice, entry: entry2, invoice_number: "INVOICENUMBER 2", invoice_date: today)
      create(:broker_invoice_line, broker_invoice: bi, charge_code: "0001", charge_description: "DUTY", charge_amount: 117.07)

      snapshot = JSON.parse CoreModule::ENTRY.entity_json(entry2)

      allow_any_instance_of(EntitySnapshot).to receive(:snapshot_json) do |snap|
        if snap.recordable == entry
          broker_invoice_with_all_charges_snapshot
        elsif snap.recordable == entry2
          snapshot
        end
      end

      data = nil
      expect(subject).to receive(:ftp_file) do |file, _opts|
        expect(File.basename(file).split("_").first).to eq "ASC"
        data = file.read
      end

      subject.generate_and_send "ASCE"

      lines = CSV.parse data, col_sep: "|"

      expect(lines.length).to eq 8

      expect(lines[0]).to eq ["H", "INVOICENUMBER", "STANDARD", today.strftime("%m/%d/%Y"), "00151", "211.0", "USD", "For Customs Entry # ENTRYNO"]
      expect(lines[1]).to eq ["L", "INVOICENUMBER", "1", "00151", "46.42", "Duty", "PO 1", "151"]
      expect(lines[2]).to eq ["L", "INVOICENUMBER", "2", "00151", "50.64", "Duty", "PO 2", "7220"]
      expect(lines[3]).to eq ["L", "INVOICENUMBER", "3", "00151", "113.94", "Duty", "PO 3", "7218"]
      expect(lines[4]).to eq ["H", "INVOICENUMBER 2", "STANDARD", today.strftime("%m/%d/%Y"), "00151", "117.07", "USD", "For Customs Entry # ENTRYNO 2"]
      expect(lines[5]).to eq ["L", "INVOICENUMBER 2", "1", "00151", "25.75", "Duty", "PO 1", "151"] # extra penny applied
      expect(lines[6]).to eq ["L", "INVOICENUMBER 2", "2", "00151", "28.1", "Duty", "PO 2", "7220"]
      expect(lines[7]).to eq ["L", "INVOICENUMBER 2", "3", "00151", "63.22", "Duty", "PO 3", "7218"]
    end

    it "Prefixes file with 'MAUR' for Maurices entry" do
      entry.update! customer_number: "MAUR"

      expect(subject).to receive(:ftp_file) do |file, _opts|
        expect(File.basename(file).split("_").first).to eq "MAUR"
      end

      expect(Lock).to receive(:db_lock).with(entry).and_yield

      subject.generate_and_send "MAUR"
    end

    it "uses the correct ftp information" do
      ftp_opts = {}
      expect(subject).to receive(:ftp_sync_file) do |_file, _sr, opts|
        ftp_opts = opts
      end

      now = ActiveSupport::TimeZone["America/New_York"].parse "today.strftime('%d-%m-%Y) 12:10:09"
      Timecop.freeze(now) { subject.generate_and_send "ASCE" }

      expect(ftp_opts[:server]).to eq "connect.vfitrack.net"
      expect(ftp_opts[:username]).to eq "www-vfitrack-net"
      expect(ftp_opts[:folder]).to eq "to_ecs/_ascena_billing"
      expect(ftp_opts[:remote_file_name]).to eq "ASC_DUTY_INVOICE_FTZ_AP_#{now.strftime('%Y%m%d%H%M%S%L')}.dat"

      # Make sure the sync record is created...
      broker_invoice.reload

      expect(broker_invoice.sync_records.length).to eq 1
      sr = broker_invoice.sync_records.first
      expect(sr.trading_partner).to eq "ASCE_DUTY_BILLING"
      expect(sr.sent_at).to eq now
    end

    it "does not send if already synced with legacy code" do
      broker_invoice.sync_records.create! trading_partner: "ASCE_BILLING", sent_at: 10.minutes.ago, confirmed_at: 5.minutes.ago
      broker_invoice.update! updated_at: 1.day.ago
      expect(subject).not_to receive(:ftp_sync_file)
      subject.generate_and_send "ASCE"
    end

    it "does not send if already synced with new codes" do
      broker_invoice.sync_records.create! trading_partner: "ASCE_DUTY_BILLING", sent_at: 10.minutes.ago, confirmed_at: 5.minutes.ago
      broker_invoice.update! updated_at: 1.day.ago
      expect(subject).not_to receive(:ftp_sync_file)
      subject.generate_and_send "ASCE"
    end

    it "does not send if ever synced with new codes" do
      # Give invoice more recent update than sync record
      broker_invoice.sync_records.create! trading_partner: "ASCE_DUTY_BILLING", sent_at: 10.minutes.ago, confirmed_at: 5.minutes.ago
      broker_invoice.update! updated_at: 2.minutes.ago
      expect(subject).not_to receive(:ftp_sync_file)
      subject.generate_and_send "ASCE"
    end

    it "does not send if business rules have failed" do
      expect_any_instance_of(Entry).to receive(:any_failed_rules?).and_return true

      expect(subject).not_to receive(:ftp_file)
      subject.generate_and_send "ASCE"
    end

    it "does not send unless entry type is '06'" do
      entry.update! entry_type: "01"

      expect(subject).not_to receive(:ftp_file)
      subject.generate_and_send "ASCE"
    end

    it "does not send unless first_entry_sent_date is present" do
      entry.update! first_entry_sent_date: nil

      expect(subject).not_to receive(:ftp_file)
      subject.generate_and_send "ASCE"
    end

    it "does not send if invoice date is more than a year old" do
      broker_invoice.update! invoice_date: today - (1.year + 1.day)

      expect(subject).not_to receive(:ftp_file)
      subject.generate_and_send "ASCE"
    end

    context "with duty credits" do
      let (:broker_invoice_duty_credit) do
        duty_line = broker_invoice_line_duty
        duty_invoice = duty_line.broker_invoice
        invoice = create(:broker_invoice, entry: duty_line.broker_invoice.entry, invoice_number: duty_invoice.invoice_number + "V", invoice_date: today + 1.day)
        create(:broker_invoice_line, broker_invoice: invoice, charge_code: "0001", charge_amount: duty_line.charge_amount * -1)

        invoice
      end

      let (:broker_invoice_duty_credit_snapshot) do
        entry.broker_invoices << broker_invoice_line_duty.broker_invoice
        entry.broker_invoices << broker_invoice_duty_credit

        entry.reload
        JSON.parse CoreModule::ENTRY.entity_json(entry)
      end

      let (:original_duty_sync_record) do
        sent = today
        sr = broker_invoice_line_duty.broker_invoice.sync_records.create! trading_partner: "ASCE_DUTY_BILLING", sent_at: sent, confirmed_at: sent + 5.minutes
        bi = broker_invoice_line_duty.broker_invoice
        bi.updated_at = sent - 1.day
        bi.save!
        sr
      end

      let (:ftp_session_attachment) do
        ftp_session = original_duty_sync_record.create_ftp_session
        original_duty_sync_record.save!
        ftp_session.create_attachment attached_file_name: "ASCE_DUTY_BILLING.csv"
      end

      let (:duty_file_data) do
        "H|INVOICENUMBER|STANDARD|#{today.strftime("%m/%d/%Y")}|00151|100.0|USD|For Customs Entry # ENTRYNO\n" \
          "L|INVOICENUMBER|1|00151|30.0|Duty|PO 1|7218"
      end

      before do
        allow_any_instance_of(EntitySnapshot).to receive(:snapshot_json).and_return(broker_invoice_duty_credit_snapshot)
        mock_attachment_download("Entry" => suppl_file, "FtpSession" => StringIO.new(duty_file_data))
      end

      it "issues a duty credit by downloading and manually reversing a previously sent billing file" do
        ftp_session_attachment
        broker_invoice_duty_credit_snapshot

        ftp_data = nil
        expect(subject).to receive(:ftp_sync_file) do |file, _sr, _opts|
          ftp_data = file.read
        end

        subject.generate_and_send "ASCE"

        expect(ftp_data).not_to be_nil
        rows = CSV.parse(ftp_data, col_sep: "|")

        expect(rows.length).to eq 2
        expect(rows.first).to eq ["H", "INVOICENUMBERV", "CREDIT", (today + 1.day).strftime("%m/%d/%Y"), "00151", "-100.0", "USD", "For Customs Entry # ENTRYNO"]
        expect(rows.second).to eq ["L", "INVOICENUMBERV", "1", "00151", "-30.0", "Duty", "PO 1", "7218"]

        expect(broker_invoice_duty_credit.sync_records.length).to eq 1
        sr = broker_invoice_duty_credit.sync_records.first
        expect(sr.trading_partner).to eq "ASCE_DUTY_BILLING"
        expect(sr.sent_at).not_to be_nil
      end
    end

    context "with duty correction billed" do
      let! (:broker_invoice_line_duty_correction) do
        broker_invoice_line_duty.update! charge_code: "0255", charge_description: "PO 1"
        broker_invoice_line_duty
      end

      let! (:broker_invoice_line_2_duty_correction) do
        broker_invoice_line_duty_direct.update! charge_code: "0255", charge_description: "PO 2"
        broker_invoice_line_duty_direct
      end

      before do
        allow_any_instance_of(EntitySnapshot).to receive(:snapshot_json).and_return(broker_invoice_with_duty_snapshot)
      end

      it "sends billing file for duty corrections" do
        data = nil
        expect(subject).to receive(:ftp_file) do |file, _opts|
          expect(File.basename(file).split("_").first).to eq "ASC"
          data = file.read
        end

        subject.generate_and_send "ASCE"

        lines = CSV.parse data, col_sep: "|"

        expect(lines.length).to eq 3
        expect(lines[0]).to eq ["H", "INVOICENUMBER", "STANDARD", today.strftime("%m/%d/%Y"), "77519", "311.0", "USD", "For Customs Entry # ENTRYNO"]
        expect(lines[1]).to eq ["L", "INVOICENUMBER", "1", "77519", "211.0", "Duty", "PO 1", "151"]
        expect(lines[2]).to eq ["L", "INVOICENUMBER", "2", "77519", "100.0", "Duty", "PO 2", "7220"]
      end

      it "uses fuzzy matching to determine correct PO number to use" do
        broker_invoice_line_duty_correction.update! charge_description: "1"
        broker_invoice_line_2_duty_correction.update! charge_description: "2"
        data = nil
        expect(subject).to receive(:ftp_file) do |file, _opts|
          expect(File.basename(file).split("_").first).to eq "ASC"
          data = file.read
        end

        subject.generate_and_send "ASCE"

        lines = CSV.parse data, col_sep: "|"

        expect(lines.length).to eq 3
        expect(lines[0]).to eq ["H", "INVOICENUMBER", "STANDARD", today.strftime("%m/%d/%Y"), "77519", "311.0", "USD", "For Customs Entry # ENTRYNO"]
        expect(lines[1]).to eq ["L", "INVOICENUMBER", "1", "77519", "211.0", "Duty", "PO 1", "151"]
        expect(lines[2]).to eq ["L", "INVOICENUMBER", "2", "77519", "100.0", "Duty", "PO 2", "7220"]
      end
    end
  end
end

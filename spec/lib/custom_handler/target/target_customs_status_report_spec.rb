describe OpenChain::CustomHandler::Target::TargetCustomsStatusReport do

  describe "run_schedulable" do
    it "calls the actual run method" do
      settings = {'email' => 'a@b.com'}
      expect(described_class).to receive(:new).and_return subject
      expect(subject).to receive(:run_customs_status_report).with(settings)

      described_class.run_schedulable(settings)
    end
  end

  describe "run_customs_status_report" do
    it "raises an exception if blank email param is provided" do
      expect(subject).not_to receive(:generate_report)

      expect { subject.run_customs_status_report({'email' => ' '}) }.to raise_error("Email address is required.")
    end

    it "raises an exception if no email param is provided" do
      expect(subject).not_to receive(:generate_report)

      expect { subject.run_customs_status_report({}) }.to raise_error("Email address is required.")
    end

    it "generates and emails spreadsheet" do
      entry_1 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-1", source_system: "Alliance",
                                departments: "A\n B", po_numbers: "C\n D",
                                docs_received_date: Date.new(2018, 12, 23), import_date: Date.new(2018, 12, 25),
                                entry_filed_date: Date.new(2018, 12, 27), lading_port_code: "XYZA", unlading_port_code: "BCDE",
                                vessel: "SS Minnow", master_bills_of_lading: "E\n F", container_numbers: "G\n H")
      entry_1.entry_exceptions.create! code: "ARF", comments: "You're the exception now, dog."
      # This exception is not included because it is resolved.
      entry_1.entry_exceptions.create! code: "BOW", comments: "X", resolved_date: Date.new(2018, 12, 29)
      entry_1.entry_exceptions.create! code: "WOW"
      entry_1.containers.create! container_number: "G"
      entry_1.containers.create! container_number: "H"

      entry_2 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-2", source_system: "Alliance",
                                departments: "B", po_numbers: "D",
                                docs_received_date: Date.new(2019, 12, 23), import_date: Date.new(2019, 12, 25),
                                entry_filed_date: Date.new(2019, 12, 27), lading_port_code: "AZYX", unlading_port_code: "EDCB",
                                vessel: "Venture X-2", master_bills_of_lading: "F", container_numbers: "H")
      entry_2.entry_exceptions.create! code: "CRH", comments: "This is a Target exception."
      entry_2.entry_exceptions.create! code: "FW", comments: "Yep"

      # The exceptions for this entry are all resolved.  An exception-content-free line should be
      # included on the report still, however, because it doesn't have a first release date.
      entry_3 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-3", source_system: "Alliance",
                                departments: "C", po_numbers: "E", docs_received_date: Date.new(2019, 12, 24), import_date: Date.new(2019, 12, 26),
                                entry_filed_date: Date.new(2019, 12, 28), lading_port_code: "BZYX", unlading_port_code: "FDCB",
                                vessel: "Venture X-3", master_bills_of_lading: "G", container_numbers: "I")
      entry_3.entry_exceptions.create! code: "BOW", resolved_date: Date.new(2018, 12, 29), comments: "This exception was resolved."
      entry_3.entry_exceptions.create! code: "WOW", resolved_date: Date.new(2018, 12, 31), comments: "Safely resolved"

      # This entry has no unresolved exceptions, has an "FDA" PGA summary record and has a one USG date.  It should not be
      # included in the report.
      entry_4 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-4", source_system: "Alliance",
                                one_usg_date: Date.new(2020, 1, 1), departments: "D")
      entry_4.entry_pga_summaries.create! agency_code: "FDA", total_claimed_pga_lines: 1

      # This entry has an unresolved exception.  Even though it has first release date, it should still show up on the report.
      entry_5 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-5", source_system: "Alliance",
                                first_release_date: Date.new(2020, 1, 1), departments: "E")
      entry_5.entry_exceptions.create! code: "ARF"

      # This entry should be excluded because its source system is not Alliance.
      entry_6 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-6", source_system: "Axis",
                                usda_hold_date: Date.new(2019, 12, 19), departments: "F")
      entry_6.entry_exceptions.create! code: "ARF"

      # This entry has no exceptions, and no FDA/EPA PGA summary.  It should be included because it has no First
      # Release Date value.
      entry_7 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-7", source_system: "Alliance",
                                one_usg_date: Date.new(2020, 1, 1), departments: "G")
      entry_7.entry_pga_summaries.create! agency_code: "FCC", total_claimed_pga_lines: 1

      # This entry isn't Target's.  Excluded, obviously.
      Factory(:entry, customer_number: "ARGENT", broker_reference: "entry-8", source_system: "Alliance", departments: "H")

      # This entry has no unresolved exceptions, has an "EPA" PGA summary record and has a one USG date.  It should not be
      # included in the report.
      entry_9 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-9", source_system: "Alliance",
                                one_usg_date: Date.new(2020, 1, 1), departments: "I")
      entry_9.entry_pga_summaries.create! agency_code: "EPA", total_claimed_pga_lines: 1

      # This entry has no unresolved exceptions, has an "EPA" PGA summary record and has a one USG date.  It should be
      # included in the report because its PGA summary record has no claimed lines, effectively negating its presence,
      # and it does not have a first release date.
      entry_10 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-10", source_system: "Alliance",
                                 one_usg_date: Date.new(2020, 1, 1), po_numbers: "J")
      entry_10.entry_pga_summaries.create! agency_code: "EPA", total_claimed_pga_lines: 0

      # These are shell entries and should be excluded despite having no one USG date.
      Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-11", source_system: "Alliance")
      Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-12", source_system: "Alliance", departments: "", po_numbers: " ")

      # This entry should be included because it has an "FDA" PGA summary record, no one USG date and an FDA message
      # that does not include "MAY PROCEED".
      entry_13 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-13", source_system: "Alliance",
                                 departments: "K", fda_message: "FDA RELEASED")
      entry_13.entry_pga_summaries.create! agency_code: "FDA", total_claimed_pga_lines: 1

      # This "FDA" PGA summary entry gets excluded despite having no one USG date because its FDA message includes "MAY PROCEED".
      entry_14 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-14", source_system: "Alliance",
                                 departments: "L", fda_message: "something may proceed something else")
      entry_14.entry_pga_summaries.create! agency_code: "FDA", total_claimed_pga_lines: 1

      # This "EPA" PGA summary entry with no one USG date is not excluded by FDA message text "MAY PROCEED".
      # That is behavior specific to FDA entries.  The entry comments don't contain the exact EPA MAY PROCEED content either.
      entry_15 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-15", source_system: "Alliance",
                                 departments: "M", fda_message: "MAY PROCEED")
      entry_15.entry_pga_summaries.create! agency_code: "EPA", total_claimed_pga_lines: 1
      entry_15.entry_comments.create! body: "08/18 13:30 EPA Entry Dsp: 07 MAY PROCEED", username: "CUSTOMS"

      # Entry comments prevent this from being included.
      entry_16 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-16", source_system: "Alliance", departments: "N")
      entry_16.entry_pga_summaries.create! agency_code: "EPA", total_claimed_pga_lines: 1
      entry_16.entry_comments.create! body: "EPA TS1 Ln 1 PG 1 Dsp: 07 MAY PROCEED", username: "CUSTOMS"

      # Same here: should not be included.  Testing case insensitivity.
      entry_17 = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-17", source_system: "Alliance", departments: "O")
      entry_17.entry_pga_summaries.create! agency_code: "EPA", total_claimed_pga_lines: 1
      entry_17.entry_comments.create! body: "epa PS3 may proceed", username: "CUSTOMS"

      Timecop.freeze(make_eastern_date(2019, 9, 30)) do
        subject.run_customs_status_report({'email' => 'a@b.com'})
      end

      expect(ActionMailer::Base.deliveries.length).to eq 1
      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eq ["a@b.com"]
      expect(mail.subject).to eq "Target Customs Status Report"
      expect(mail.body).to include "Attached is the Customs Status Report."

      att = mail.attachments["Target_Customs_Status_Report_2019-09-30.xlsx"]
      expect(att).not_to be_nil
      reader = XlsxTestReader.new(StringIO.new(att.read)).raw_workbook_data
      expect(reader.length).to eq 1

      sheet = reader["Exceptions"]
      expect(sheet).not_to be_nil
      expect(sheet.length).to eq 11
      expect(sheet[0]).to eq ["Importer", "Broker", "File No.", "Dept", "P.O.", "Doc Rec'd Date", "ETA", "ABI Date",
                              "Reason Code", "Comments from Broker", "No of Cntrs", "Port of Lading", "Port of Unlading",
                              "Vessel", "Bill of Lading Number", "Containers"]
      expect(sheet[1]).to eq ["TGMI", "316", "entry-1", "A,B", "C,D", Date.new(2018, 12, 23), Date.new(2018, 12, 25),
                              Date.new(2018, 12, 27), "ARF", "You're the exception now, dog.", 2, "XYZA", "BCDE", "SS Minnow", "E,F", "G,H"]
      expect(sheet[2]).to eq ["TGMI", "316", "entry-1", "A,B", "C,D", Date.new(2018, 12, 23), Date.new(2018, 12, 25),
                              Date.new(2018, 12, 27), "WOW", nil, 2, "XYZA", "BCDE", "SS Minnow", "E,F", "G,H"]
      expect(sheet[3]).to eq ["TGMI", "316", "entry-2", "B", "D", Date.new(2019, 12, 23), Date.new(2019, 12, 25),
                              Date.new(2019, 12, 27), "F&W", "Yep", 0, "AZYX", "EDCB", "Venture X-2", "F", "H"]
      expect(sheet[4]).to eq ["TGMI", "316", "entry-2", "B", "D", Date.new(2019, 12, 23), Date.new(2019, 12, 25),
                              Date.new(2019, 12, 27), "TGT", "This is a Target exception.", 0, "AZYX", "EDCB", "Venture X-2", "F", "H"]
      expect(sheet[5]).to eq ["TGMI", "316", "entry-3", "C", "E", Date.new(2019, 12, 24), Date.new(2019, 12, 26),
                              Date.new(2019, 12, 28), nil, nil, 0, "BZYX", "FDCB", "Venture X-3", "G", "I"]
      expect(sheet[6]).to eq ["TGMI", "316", "entry-5", "E", nil, nil, nil, nil, "ARF", nil, 0, nil, nil, nil, nil, nil]
      expect(sheet[7]).to eq ["TGMI", "316", "entry-7", "G", nil, nil, nil, nil, nil, nil, 0, nil, nil, nil, nil, nil]
      expect(sheet[8]).to eq ["TGMI", "316", "entry-10", nil, "J", nil, nil, nil, nil, nil, 0, nil, nil, nil, nil, nil]
      expect(sheet[9]).to eq ["TGMI", "316", "entry-13", "K", nil, nil, nil, nil, nil, nil, 0, nil, nil, nil, nil, nil]
      expect(sheet[10]).to eq ["TGMI", "316", "entry-15", "M", nil, nil, nil, nil, nil, nil, 0, nil, nil, nil, nil, nil]
    end

    def make_utc_date year, month, day
      ActiveSupport::TimeZone["UTC"].parse("#{year}-#{month}-#{day} 16:00")
    end

    def make_eastern_date year, month, day
      dt = make_utc_date(year, month, day)
      dt = dt.in_time_zone(ActiveSupport::TimeZone["America/New_York"])
      dt
    end
  end

end
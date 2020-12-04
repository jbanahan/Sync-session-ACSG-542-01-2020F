describe OpenChain::CustomHandler::Target::TargetCustomsStatusReport do

  describe "run_schedulable" do
    it "calls the actual run method" do
      settings = {'email' => 'a@b.com'}
      expect(described_class).to receive(:new).and_return subject
      expect(subject).to receive(:run_customs_status_report).with(settings)

      described_class.run_schedulable(settings)
    end
  end

  describe "entries" do
    let!(:entry) do
      Factory(:entry, customer_number: "TARGEN", source_system: "Alliance", one_usg_date: nil, first_release_date: nil,
                      po_numbers: "PO", departments: "DEPT")
    end

    let(:date) { Date.new 2020, 3, 15 }

    it "returns entries" do
      expect(subject.entries).to eq [entry]
    end

    it "excludes non-Target" do
      entry.update! customer_number: "Crudco"
      expect(subject.entries).to be_empty
    end

    it "excludes non-Alliance" do
      entry.update! source_system: "Fenix"
      expect(subject.entries).to be_empty
    end

    it "excludes entries that are missing both PO numbers and departments (header level)" do
      entry.update! po_numbers: nil, departments: ""
      expect(subject.entries).to be_empty
    end

    it "includes entries that have One USG and unresolved exceptions" do
      entry.update! one_usg_date: date
      entry.entry_exceptions.create! code: "ARF", resolved_date: nil
      expect(subject.entries).to eq [entry]
    end

    it "includes entries that have first release and unresolved exceptions" do
      entry.update! first_release_date: date
      entry.entry_exceptions.create! code: "ARF", resolved_date: nil
      expect(subject.entries).to eq [entry]
    end

    it "excludes entries that have both One USG and first release but no unresolved exceptions" do
      entry.update! one_usg_date: date, first_release_date: date
      entry.entry_exceptions.create! code: "ARF", resolved_date: date
      expect(subject.entries).to be_empty
    end
  end

  describe "include_entry?" do
    subject { described_class.new }

    let(:ent) do
      entry = Factory(:entry, one_usg_date: nil, first_release_date: nil, fda_message: "TAKE VITAMIN SUPPLEMENTS!")
      entry.entry_comments.create! username: "CUSTOMS", body: "EPA says nothin' doin'"
      entry
    end

    context "standard entry" do
      it "returns true if there's no first release" do
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("FDA", claimed_pga_lines_only: true).and_return false
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("EPA", claimed_pga_lines_only: true).and_return false

        expect(subject.include_entry?(ent)).to eq true
      end

      it "returns false if first release received" do
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("FDA", claimed_pga_lines_only: true).and_return false
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("EPA", claimed_pga_lines_only: true).and_return false

        ent.update! first_release_date: Date.new(2020, 3, 15)
        expect(subject.include_entry?(ent)).to eq false
      end
    end

    context "FDA entry" do
      it "returns true if no One USG and no 'proceed' message" do
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("FDA", claimed_pga_lines_only: true).and_return true

        expect(subject.include_entry?(ent)).to eq true
      end

      it "returns false if One USG received" do
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("FDA", claimed_pga_lines_only: true).and_return true

        ent.update! one_usg_date: Date.new(2020, 3, 15)
        expect(subject.include_entry?(ent)).to eq false
      end

      it "returns false if there's a 'may proceed' message" do
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("FDA", claimed_pga_lines_only: true).and_return true

        ent.update! fda_message: "You may proceed!"
        expect(subject.include_entry?(ent)).to eq false
      end
    end

    context "EPA entry" do
      it "returns true if no One USG and no 'proceed' message" do
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("FDA", claimed_pga_lines_only: true).and_return false
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("EPA", claimed_pga_lines_only: true).and_return true

        expect(subject.include_entry?(ent)).to eq true
      end

      it "returns false if One USG received" do
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("FDA", claimed_pga_lines_only: true).and_return false
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("EPA", claimed_pga_lines_only: true).and_return true

        ent.update! one_usg_date: Date.new(2020, 3, 15)
        expect(subject.include_entry?(ent)).to eq false
      end

      it "returns false if there's a 'proceed' message" do
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("FDA", claimed_pga_lines_only: true).and_return false
        expect(ent).to receive(:includes_pga_summary_for_agency?).with("EPA", claimed_pga_lines_only: true).and_return true

        ent.entry_comments.create! username: "CUSTOMS", body: "EPA says that you may proceed!"
        expect(subject.include_entry?(ent)).to eq false
      end
    end
  end

  describe "convert_reason_code" do
    it "converts 'CRH' to 'TGT'" do
      expect(subject.convert_reason_code("CRH")).to eq "TGT"
    end

    it "converts 'FW' to 'F&W'" do
      expect(subject.convert_reason_code("FW")).to eq "F&W"
    end

    it "leaves others unchanged" do
      expect(subject.convert_reason_code("FOO")).to eq "FOO"
    end
  end

  describe "run_customs_status_report" do
    let(:entry_1) do
      ent = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-1", source_system: "Alliance",
                            departments: "filler", po_numbers: "filler", docs_received_date: Date.new(2018, 12, 23),
                            import_date: Date.new(2018, 12, 25), entry_filed_date: Date.new(2018, 12, 27), lading_port_code: "XYZA",
                            unlading_port_code: "BCDE", vessel: "SS Minnow")

      ent.entry_exceptions.create! code: "WOW"
      ent.entry_exceptions.create! code: "ARF", comments: "You're the exception now, dog."

      ci_1 = Factory(:commercial_invoice, entry: ent, invoice_number: "MBOL 1")
      Factory(:commercial_invoice_line, commercial_invoice: ci_1, department: "dept 1", po_number: "PO 1")

      ci_2 = Factory(:commercial_invoice, entry: ent, invoice_number: "MBOL 2")
      Factory(:commercial_invoice_line, commercial_invoice: ci_2, department: "dept 2", po_number: "PO 2")

      ent.bill_of_ladings.create! bill_type: "master", bill_number: "MBOL 1", containers: [ent.containers.create!(container_number: "G")]
      ent.bill_of_ladings.create! bill_type: "master", bill_number: "MBOL 2", containers: [ent.containers.create!(container_number: "H")]

      ent
    end

    let(:entry_2) do
      ent = Factory(:entry, customer_number: "TARGEN", broker_reference: "entry-2", source_system: "Alliance",
                            departments: "filler", po_numbers: "filler", docs_received_date: Date.new(2019, 12, 23),
                            import_date: Date.new(2019, 12, 25), entry_filed_date: Date.new(2019, 12, 27),
                            lading_port_code: "AZYX", unlading_port_code: "EDCB", vessel: "Venture X-2")

      ci = Factory(:commercial_invoice, entry: ent, invoice_number: "MBOL 3")
      Factory(:commercial_invoice_line, commercial_invoice: ci, department: "dept 3", po_number: "PO 3")

      ent.bill_of_ladings.create! bill_type: "master", bill_number: "MBOL 3", containers: [ent.containers.create!(container_number: "I")]

      ent
    end

    it "raises an exception if blank email param is provided" do
      expect(subject).not_to receive(:generate_report)

      expect { subject.run_customs_status_report({'email' => ' '}) }.to raise_error("Email address is required.")
    end

    it "raises an exception if no email param is provided" do
      expect(subject).not_to receive(:generate_report)

      expect { subject.run_customs_status_report({}) }.to raise_error("Email address is required.")
    end

    it "generates and emails spreadsheet" do
      entry_1; entry_2

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
      expect(sheet.length).to eq 6
      expect(sheet[0]).to eq ["Importer", "Broker", "File No.", "Dept", "P.O.", "Doc Rec'd Date", "ETA",
                              "ABI Date", "Reason Code", "Comments from Broker", "No of Cntrs", "Port of Lading", "Port of Unlading", "Vessel",
                              "Bill of Lading Number", "Containers", "Consolidated Entry"]

      # first entry
      expect(sheet[1]).to eq ["TGMI", "316", "entry-1", "dept 1", "PO 1", Date.new(2018, 12, 23), Date.new(2018, 12, 25),
                              Date.new(2018, 12, 27), "ARF", "You're the exception now, dog.", 1, "XYZA", "BCDE", "SS Minnow",
                              "MBOL 1", "G", "Y"]

      expect(sheet[2]).to eq ["TGMI", "316", "entry-1", "dept 2", "PO 2", Date.new(2018, 12, 23), Date.new(2018, 12, 25),
                              Date.new(2018, 12, 27), "ARF", "You're the exception now, dog.", 1, "XYZA", "BCDE", "SS Minnow",
                              "MBOL 2", "H", "Y"]

      expect(sheet[3]).to eq ["TGMI", "316", "entry-1", "dept 1", "PO 1", Date.new(2018, 12, 23), Date.new(2018, 12, 25),
                              Date.new(2018, 12, 27), "WOW", nil, 1, "XYZA", "BCDE", "SS Minnow",
                              "MBOL 1", "G", "Y"]

      expect(sheet[4]).to eq ["TGMI", "316", "entry-1", "dept 2", "PO 2", Date.new(2018, 12, 23), Date.new(2018, 12, 25),
                              Date.new(2018, 12, 27), "WOW", nil, 1, "XYZA", "BCDE", "SS Minnow",
                              "MBOL 2", "H", "Y"]

      # second entry
      expect(sheet[5]).to eq ["TGMI", "316", "entry-2", "dept 3", "PO 3", Date.new(2019, 12, 23), Date.new(2019, 12, 25),
                              Date.new(2019, 12, 27), nil, nil, 1, "AZYX", "EDCB", "Venture X-2",
                              "MBOL 3", "I", nil]
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

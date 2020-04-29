describe OpenChain::Report::JCrewBillingReport do

  describe "permission?" do
    let (:ms) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return true
    }

    it "allows access to master companies for www users" do
      ms
      expect(described_class.permission? Factory(:master_user)).to eq true
    end

    it "denies access to non-master users" do
      ms
      expect(described_class.permission? Factory(:user)).to eq false
    end

    it "denies access to non-www systems" do
      expect(described_class.permission? Factory(:master_user)).to eq false
    end
  end

  describe "run" do
    let! (:entry) {
      entry = Factory(:commercial_invoice_tariff, duty_amount: BigDecimal.new("50"),
                          commercial_invoice_line: Factory(:commercial_invoice_line, po_number: "123", prorated_mpf: BigDecimal.new("1.50"), hmf: BigDecimal.new("2.25"), cotton_fee: BigDecimal.new("3.50"),
                            commercial_invoice: Factory(:commercial_invoice,
                              entry: Factory(:entry, entry_number: "12345")
                          )
                        )
                      ).commercial_invoice_line.commercial_invoice.entry

      line = Factory(:broker_invoice_line, charge_type: "R", charge_amount: BigDecimal.new("100"),
        broker_invoice: Factory(:broker_invoice, customer_number: 'JCREW', invoice_date: '2014-01-01', invoice_number: "Inv#", entry: entry)
      )
      entry
    }

    subject { OpenChain::Report::JCrewBillingReport.new 'start_date' => "2014-01-01".to_date, 'end_date' => "2014-01-01".to_date }

    def extract_xlsx_data file
      io = StringIO.new
      Zip::File.open(file.path) do |zip|
        zip.file.open("JCrew Billing 2014-01-01 thru 2014-01-01.xlsx", "rb") {|f| io << f.read }
      end
      io.rewind

      XlsxTestReader.new(io).raw_workbook_data
    end

    def extract_csv_data file
      csv_files = []
      Zip::File.open(file.path) do |zip|
        csv = zip.glob('*.csv')
        csv.each do |f|
          csv_files << {name: f.name, data: CSV.parse(f.get_input_stream.read)}
        end
      end

      csv_files
    end

    it "generates a billing file for direct pos" do
      data = nil
      csv_files = nil
      now = ActiveSupport::TimeZone["UTC"].parse("2018-07-18 01:00")
      Timecop.freeze(now) do
        subject.run do |tempfile|
          data = extract_xlsx_data tempfile
          csv_files = extract_csv_data tempfile
          expect(tempfile.binmode?).to eq true
          expect(tempfile.original_filename).to eq "JCrew Billing 2014-01-01 thru 2014-01-01.zip"
        end
      end

      expect(data).not_to be_nil

      expect(data.size).to eq 1
      worksheet = data["VG-WE20180717"]
      expect(worksheet).not_to be_nil
      expect(worksheet.length).to eq 9

      # The first 5 rows are headers defining the column attributes of the different line types...we don't care about these

      expect(worksheet[5][0..6]).to eq ["Invoice", "VG-WE20180717", nil, "2003513", "Draft", "07/17/2018", "No"]
      expect(worksheet[5][10]).to eq "No"
      expect(worksheet[5][18..22]).to eq ["martha.long@jcrew.com", nil, nil, "US Purchasing", "USD"]
      expect(worksheet[5][69]).to eq "770"

      expect(worksheet[6][0..8]).to eq ["Invoice Line", "VG-WE20180717", nil, "2003513", 1, "Inv#", nil, nil, 100]
      expect(worksheet[6][17]).to eq "EA"
      expect(worksheet[6][23..29]).to eq ["JC02", "0021", "General Expense (Non IO)", "0006000", nil, nil, "211541"]

      expect(worksheet[7][0..8]).to eq ["Invoice Line", "VG-WE20180717", nil, "2003513", 2, "Inv#", nil, nil, 57.25]
      expect(worksheet[7][17]).to eq "EA"
      expect(worksheet[7][23..29]).to eq ["JC02", "0021", "General Expense (Non IO)", "0006000", nil, nil, "211521"]

      expect(worksheet[8][0..8]).to eq ["Invoice Line", "VG-WE20180717", nil, "2003513", 3, "VG-WE20180717 Credit", nil, nil, -57.25]
      expect(worksheet[8][17]).to eq "EA"
      expect(worksheet[8][23..29]).to eq ["JC02", "0022", "General Expense (Non IO)", nil, nil, nil, "111295"]

      expect(csv_files.length).to eq 1

      expect(csv_files.first[:name]).to eq "VG-WE20180717.csv"
      csv = csv_files.first[:data]

      expect(csv[5][0..6]).to eq ["Invoice", "VG-WE20180717", nil, "2003513", "Draft", "07/17/2018", "No"]
      expect(csv[5][10]).to eq "No"
      expect(csv[5][18..22]).to eq ["martha.long@jcrew.com", nil, nil, "US Purchasing", "USD"]
      expect(csv[5][69]).to eq "770"

      expect(csv[6][0..8]).to eq ["Invoice Line", "VG-WE20180717", nil, "2003513", "1", "Inv#", nil, nil, "100.0"]
      expect(csv[6][17]).to eq "EA"
      expect(csv[6][23..29]).to eq ["JC02", "0021", "General Expense (Non IO)", "0006000", nil, nil, "211541"]

      expect(csv[7][0..8]).to eq ["Invoice Line", "VG-WE20180717", nil, "2003513", "2", "Inv#", nil, nil, "57.25"]
      expect(csv[7][17]).to eq "EA"
      expect(csv[7][23..29]).to eq ["JC02", "0021", "General Expense (Non IO)", "0006000", nil, nil, "211521"]

      expect(csv[8][0..8]).to eq ["Invoice Line", "VG-WE20180717", nil, "2003513", "3", "VG-WE20180717 Credit", nil, nil, "-57.25"]
      expect(csv[8][17]).to eq "EA"
      expect(csv[8][23..29]).to eq ["JC02", "0022", "General Expense (Non IO)", nil, nil, nil, "111295"]
    end

    [
      {po_number: "2", division: "retail 2", b_a: "0023", profit_center: "0005023"},
      {po_number: "3", division: "factory 3", b_a: "0024", profit_center: "0005024"},
      {po_number: "4", division: "madewell retail", b_a: "0026", profit_center: "0005026"},
      {po_number: "5", division: "retail 5", b_a: "0023", profit_center: "0005023"},
      {po_number: "6", division: "factory direct", b_a: "0037", profit_center: "0007500"},
      {po_number: "7", division: "madewell direct", b_a: "0027", profit_center: "0007300"},
      {po_number: "8", division: "direct 8", b_a: "0021", profit_center: "0006000"},
      {po_number: "9", division: "factory 9", b_a: "0024", profit_center: "0005024"},
      {po_number: "02", division: "madewell wholesale", b_a: "0018", profit_center: "0018140"}
    ].each do |params|

      it "uses correct account information for #{params[:division]} division" do
        entry.commercial_invoice_lines.first.update_attributes po_number: params[:po_number]

        data = nil
        now = ActiveSupport::TimeZone["UTC"].parse("2018-07-18 01:00")
        Timecop.freeze(now) do
          subject.run do |tempfile|
            data = extract_xlsx_data tempfile
          end
        end

        worksheet = data["VG-WE20180717"]
        expect(worksheet).not_to be_nil
        expect(worksheet.length).to eq 9

        # The only thing that changes by division is the profit center and business account
        expect(worksheet[6][0..8]).to eq ["Invoice Line", "VG-WE20180717", nil, "2003513", 1, "Inv#", nil, nil, 100]
        expect(worksheet[6][17]).to eq "EA"
        expect(worksheet[6][23..29]).to eq ["JC02", params[:b_a], "General Expense (Non IO)", params[:profit_center], nil, nil, "211541"]
      end
    end


    it "splits brokerage charges into multiple buckets prorating by PO # counts" do
      # This should give us a total of 6 unique lines, using 100 split 6 ways is a perfect test for the proration algorithm too
      # since the 3rd po is a 1/6th proration (16.66) vs. a 1/3 proration (33.33) and it should dump the leftover cent into the highest
      # valued truncated amount (ie. the 16.66 one)
      entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "122"
      entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "133"
      entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "222"
      entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "223"
      entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "324"

      data = nil
      subject.run do |tempfile|
        data = extract_xlsx_data tempfile
      end

      worksheet = data[data.keys.first]
      expect(worksheet.length).to eq 11

      # Should have 2 rows for direct division (po starts with 1 = direct) - one row for charges and one for duty,
      # a row for retail division (po starts with 1 = retail) - one row for charges
      # a row for factory division (po starts with 3 = factory) - one row for charges
      # one row for header
      # one row for duty summary

      # Basically, just check that the expected prorated amounts are present (column 8)
      expect(worksheet[6][8]).to eq 50
      # row 2 is the duty for the direct division line - don't care about it..not something we're checking on for this test
      expect(worksheet[8][8]).to eq 33.33
      expect(worksheet[9][8]).to eq 16.67
    end

    it "splits data into multiple tabs / files if number of lines exceeds max" do
      # just create a second entry, and mock out the max line method such that each entry should appear on its own tab
      entry2 = Factory(:commercial_invoice_tariff, duty_amount: BigDecimal.new("25"),
                          commercial_invoice_line: Factory(:commercial_invoice_line, po_number: "123", prorated_mpf: BigDecimal.new("1.50"), hmf: BigDecimal.new("2.25"), cotton_fee: BigDecimal.new("3.50"),
                            commercial_invoice: Factory(:commercial_invoice,
                              entry: Factory(:entry, entry_number: "98765")
                          )
                        )
                      ).commercial_invoice_line.commercial_invoice.entry

      invoice_line2 = Factory(:broker_invoice_line, charge_type: "R", charge_amount: BigDecimal.new("50"),
        broker_invoice: Factory(:broker_invoice, customer_number: 'JCREW', invoice_date: '2014-01-01', invoice_number: "Inv#2", entry: entry2)
      )

      expect(subject).to receive(:max_row_count).at_least(1).times.and_return 4

      data = nil
      now = ActiveSupport::TimeZone["UTC"].parse("2018-07-18 01:00")
      csv_files = nil
      Timecop.freeze(now) do
        subject.run do |tempfile|
          data = extract_xlsx_data tempfile
          csv_files = extract_csv_data tempfile
        end
      end

      expect(data.keys).to eq ["VG-WE20180717A", "VG-WE20180717B"]

      inv1 = data["VG-WE20180717A"]

      # We only really need to validate the barest stuff to ensure the data is correct, pretty much just ensure the first row of line data is as expected and the final duty row amount
      expect(inv1.length).to eq 9
      expect(inv1[6][0..8]).to eq ["Invoice Line", "VG-WE20180717A", nil, "2003513", 1, "Inv#", nil, nil, 100]
      expect(inv1[8][0..8]).to eq ["Invoice Line", "VG-WE20180717A", nil, "2003513", 3, "VG-WE20180717A Credit", nil, nil, -57.25]

      inv2 = data["VG-WE20180717B"]

      expect(inv2.length).to eq 9
      expect(inv2[6][0..8]).to eq ["Invoice Line", "VG-WE20180717B", nil, "2003513", 1, "Inv#2", nil, nil, 50]
      expect(inv2[8][0..8]).to eq ["Invoice Line", "VG-WE20180717B", nil, "2003513", 3, "VG-WE20180717B Credit", nil, nil, -32.25]

      expect(csv_files.length).to eq 2
      inv1 = csv_files.find {|f| f[:name] == "VG-WE20180717A.csv"}
      expect(inv1).not_to be_nil

      inv1 = inv1[:data]
      expect(inv1.length).to eq 9
      expect(inv1[6][0..8]).to eq ["Invoice Line", "VG-WE20180717A", nil, "2003513", "1", "Inv#", nil, nil, "100.0"]
      expect(inv1[8][0..8]).to eq ["Invoice Line", "VG-WE20180717A", nil, "2003513", "3", "VG-WE20180717A Credit", nil, nil, "-57.25"]

      inv2 = csv_files.find {|f| f[:name] == "VG-WE20180717B.csv"}
      expect(inv2).not_to be_nil
      inv2 = inv2[:data]
      expect(inv2.length).to eq 9
      expect(inv2[6][0..8]).to eq ["Invoice Line", "VG-WE20180717B", nil, "2003513", "1", "Inv#2", nil, nil, "50.0"]
      expect(inv2[8][0..8]).to eq ["Invoice Line", "VG-WE20180717B", nil, "2003513", "3", "VG-WE20180717B Credit", nil, nil, "-32.25"]

    end

    context "with outputs yielding no invoice lines" do
      after :each do
        data = nil
        subject.run do |tempfile|
          data = extract_xlsx_data tempfile
        end

        expect(data["No Invoice"]).not_to be_nil
        expect(data["No Invoice"][0]).to eq ["No billing data returned for this report."]
      end

      it "doesn't add entry information when invoice amounts for the date range zero each other out" do
        inv2 = entry.broker_invoices.create! invoice_number: "2", invoice_date: '2014-01-01', customer_number: "J0000"
        inv2.broker_invoice_lines.create! charge_amount: BigDecimal.new("-100"), charge_description: "Blank", charge_code: "123", charge_type: "R"
      end

      it "ignores charge codes over 1000" do
        entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_code: 1001
      end

      ["COST", "FREIGHT", "DUTY", "WAREHOUSE"].each do |charge_desc|
        it "ignores lines with '#{charge_desc}' in description" do
          entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_description: charge_desc
        end
      end

      it "ignores lines with charge codes in massive exclusion list" do
        entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_code: 999
      end
    end
  end

  describe "run_schedulable" do

    subject { described_class }

    let (:tempfile) {
      t = Tempfile.open(["Temp", ".xlsx"])
      # Needs to have data, otherwise it's not emailed by mailer
      t << "Data"
      t.flush
      Attachment.add_original_filename_method t, "report.xlsx"
      t
    }

    after :each do
      tempfile.close! unless tempfile.closed?
    end

    it "emails report to given user from opts date range of previous week" do
      now = ActiveSupport::TimeZone["America/New_York"].parse("2018-07-20 12:00")
      expect(subject).to receive(:run_report).with(User.integration, {start_date: "2018-07-08", end_date: "2018-07-14"}).and_yield tempfile
      Timecop.freeze(now) { subject.run_schedulable({email_to: "user@domain.com"}) }

      m = ActionMailer::Base.deliveries.first
      expect(m).not_to be_nil
      expect(m.to).to eq ["user@domain.com"]
      expect(m.subject).to eq "J Crew Billing 07/08/2018 - 07/14/2018"
      expect(m.attachments["report.xlsx"]).not_to be_nil
    end

    it "uses given date range" do
      expect(subject).to receive(:run_report).with(User.integration, {start_date: "2018-07-01", end_date: "2018-07-07"}).and_yield tempfile

      subject.run_schedulable({email_to: "user@domain.com", start_date: "2018-07-01", end_date: "2018-07-07"})

      m = ActionMailer::Base.deliveries.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "J Crew Billing 07/01/2018 - 07/07/2018"
    end

    it "errors if email is not given" do
      expect { subject.run_schedulable }.to raise_error "Email address is required."
    end
  end
end
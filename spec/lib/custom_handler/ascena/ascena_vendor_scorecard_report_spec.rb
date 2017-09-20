describe OpenChain::CustomHandler::Ascena::AscenaVendorScorecardReport do

  subject { described_class }

  let! (:ascena) {
    ascena = Factory(:importer, system_code: "ASCENA")
    ascena
  }

  describe "permission?" do
  
    before(:each) do
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return "www-vfitrack-net"
    end

    it "allows access for master users who can view entries" do
      u = Factory(:master_user)
      expect(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for Ascena users who can view entries" do
      u = Factory(:user)
      u.company.system_code = 'ASCENA'
      expect(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for users of Ascena's linked companies" do
      partner = Factory(:company, linked_companies: [ascena])
      u = Factory(:user, company: partner)
      expect(u).to receive(:view_entries?).and_return true
      expect(described_class.permission? u).to eq true
    end

    it "prevents access by other companies" do
      u = Factory(:user)
      u.company.system_code = 'NOT ASCENA'
      expect(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq false
    end

    it "prevents access by users who can't view entries" do
      u = Factory(:master_user)
      expect(u).to receive(:view_entries?).and_return false
      expect(subject.permission? u).to eq false
    end
  end

  describe "run_report" do

    let! (:entry) {
      e = Factory(:entry, importer: ascena, entry_number: "entry_no", customer_number: "ASCE", fiscal_date: Date.new(2017, 3, 1), first_release_date: DateTime.new(2017, 3, 1, 5, 0))

      inv = e.commercial_invoices.create! invoice_number: "INV"

      line = inv.commercial_invoice_lines.create! po_number: "PO", contract_amount: 5.43, mid: "mid12345", value: 2.43, product_line: "prodlineA", part_number: "part_X"
      tariff = line.commercial_invoice_tariffs.create! entered_value: BigDecimal("10"), duty_amount: BigDecimal("1")

      # No first sale claim on this line
      line2 = inv.commercial_invoice_lines.create! po_number: "PO", contract_amount: 0, mid: line.mid, value: 1.21, product_line: "prodlineA2", part_number: "part_X"
      tariff2 = line2.commercial_invoice_tariffs.create! entered_value: BigDecimal("10"), duty_amount: BigDecimal("1")

      line3 = inv.commercial_invoice_lines.create! po_number: "PO2", contract_amount: 1.56, mid: "mid23456", value: 3.45, product_line: "prodlineB", part_number: "part_Y"
      tariff3 = line3.commercial_invoice_tariffs.create! entered_value: BigDecimal("10"), duty_amount: BigDecimal("1")

      line4 = inv.commercial_invoice_lines.create! po_number: "PO3", contract_amount: 1.67, mid: "mid12345", value: 0.25, product_line: "prodlineC", part_number: "part_Z"
      tariff4 = line4.commercial_invoice_tariffs.create! entered_value: BigDecimal("10"), duty_amount: BigDecimal("1")

      DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid12345-suffix_to_be_ignored", value: "2017-01-01")
      DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid23456-X", value: "2016-12-25")

      vendor = Factory(:company, name: "Ascena Vendor")
      vendor2 = Factory(:company, name: "Ascena Vendor 2")
      factory = Factory(:company, name: "Crapco Industries")
      factory2 = Factory(:company, name: "Carpco Deluxe Knock-offs")

      order1 = Factory(:order, order_number: "ASCENA-PO", vendor: vendor, factory: factory)
      order2 = Factory(:order, order_number: "ASCENA-PO2", vendor: vendor, factory: factory2)
      order3 = Factory(:order, order_number: "ASCENA-PO3", vendor: vendor2, factory: factory)

      e
    }

    it "runs release-date-based report" do
      tf = subject.run_report nil, {"range_field" => "first_release_date", "start_release_date" => "2017-02-25", "end_release_date" => "2017-03-25"}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      expect(sheet = wb.worksheet("Vendor")).not_to be_nil
      expect(sheet.rows.count).to eq 6
      expect(sheet.row(0)).to eq ["<Summary by vendor>", nil, nil, nil, nil, nil]
      expect(sheet.row(2)).to eq ["No.", "VENDOR", "INV AMOUNT", "INV AMOUNT IN FS ELIGIBLE", "FS SAVINGS", "PENETRATION"]
      expect(sheet.row(3)).to eq [1, "Ascena Vendor", 8.2, 6.99, 0.11, 0.85]
      expect(sheet.row(4)).to eq [2, "Ascena Vendor 2", 1.67, 1.67, 0.14, 1]
      expect(sheet.row(5)).to eq [nil, "TOTAL", 9.87, 8.66, 0.25, 0.88]

      expect(sheet = wb.worksheet("Vendor Factory Pair")).not_to be_nil
      expect(sheet.rows.count).to eq 7
      expect(sheet.row(0)).to eq ["<Summary by vendor / factory pair>", nil, nil, nil, nil, nil, nil]
      expect(sheet.row(2)).to eq ["No.", "VENDOR", "FACTORY", "INV AMOUNT", "INV AMOUNT IN FS ELIGIBLE", "FS SAVINGS", "REMARKS"]
      expect(sheet.row(3)).to eq [1, "Ascena Vendor", "Carpco Deluxe Knock-offs", 1.56, 1.56, -0.19, "Eligible - 12/25/2016"]
      expect(sheet.row(4)).to eq [2, "Ascena Vendor", "Crapco Industries", 6.64, 5.43, 0.3, "Eligible - 01/01/2017"]
      expect(sheet.row(5)).to eq [3, "Ascena Vendor 2", "Crapco Industries", 1.67, 1.67, 0.14, "Eligible - 01/01/2017"]
      expect(sheet.row(6)).to eq [nil, "TOTAL", nil, 9.87, 8.66, 0.25, nil]

      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 7
      expect(sheet.row(0)).to eq ["<Detailed Data Lines>", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(2)).to eq ["No.", "VENDOR", "FACTORY", "ENTRY NUMBER", "INV AMOUNT", "FS SAVINGS", "FIRST RELEASE DATE", "INVOICE NUMBER", "VALUE", "PRODUCT LINE", "PO NUMBER", "PART NUMBER", "CONTRACT AMOUNT", "REMARKS"]
      expect(sheet.row(3)).to eq [1, "Ascena Vendor", "Carpco Deluxe Knock-offs", "entry_no", 1.56, -0.19, "03/01/2017", "INV", 3.45, "prodlineB", "PO2", "part_Y", 1.56, "Eligible - 12/25/2016"]
      expect(sheet.row(4)).to eq [2, "Ascena Vendor", "Crapco Industries", "entry_no", 5.43, 0.3, "03/01/2017", "INV", 2.43, "prodlineA", "PO", "part_X", 5.43, "Eligible - 01/01/2017"]
      expect(sheet.row(5)).to eq [3, "Ascena Vendor", "Crapco Industries", "entry_no", 1.21, 0.0, "03/01/2017", "INV", 1.21, "prodlineA2", "PO", "part_X", 0, "Eligible - 01/01/2017"]
      expect(sheet.row(6)).to eq [4, "Ascena Vendor 2", "Crapco Industries", "entry_no", 1.67, 0.14, "03/01/2017", "INV", 0.25, "prodlineC", "PO3", "part_Z", 1.67, "Eligible - 01/01/2017"]
    end

    it "runs fiscal-date-based report" do
      fiscal_month_1 = FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 1, start_date: "2017-02-25")
      fiscal_month_2 = FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 2, start_date: "2017-03-25")

      tf = subject.run_report nil, {"range_field" => "fiscal_date", "start_fiscal_year_month" => "2017-1", "end_fiscal_year_month" => "2017-2"}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      expect(sheet = wb.worksheet("Vendor")).not_to be_nil
      expect(sheet.rows.count).to eq 6

      expect(sheet = wb.worksheet("Vendor Factory Pair")).not_to be_nil
      expect(sheet.rows.count).to eq 7

      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 7
    end

    it "ignores invoice content with no MID cross reference" do
      inv2 = entry.commercial_invoices.create! invoice_number: "INV2"
      line_bad = inv2.commercial_invoice_lines.create! po_number: "PO_bad", contract_amount: 5.43, mid: "mid_bogus", value: 2.43, product_line: "prodlineA", part_number: "part_X"
      tariff_bad = line_bad.commercial_invoice_tariffs.create! entered_value: BigDecimal("10"), duty_amount: BigDecimal("1")
      vendor_bad = Factory(:company, name: "Bad Ascena Vendor")
      order_bad = Factory(:order, order_number: "ASCENA-PO_bad", vendor: vendor_bad)

      tf = subject.run_report nil, {"range_field" => "first_release_date", "start_release_date" => "2017-02-25", "end_release_date" => "2017-03-25"}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      # Row count should not be any higher than the default amount: new invoice line should not have been included in the report.
      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 7
    end

    it "ignores invoice content attached to bad MID cross reference" do
      inv2 = entry.commercial_invoices.create! invoice_number: "INV2"
      line_bad = inv2.commercial_invoice_lines.create! po_number: "PO_bad", contract_amount: 5.43, mid: "mid_bogus", value: 2.43, product_line: "prodlineA", part_number: "part_X"
      tariff_bad = line_bad.commercial_invoice_tariffs.create! entered_value: BigDecimal("10"), duty_amount: BigDecimal("1")
      vendor_bad = Factory(:company, name: "Bad Ascena Vendor")
      order_bad = Factory(:order, order_number: "ASCENA-PO_bad", vendor: vendor_bad)

      DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid_bogus", value: "invalid date")

      tf = subject.run_report nil, {"range_field" => "first_release_date", "start_release_date" => "2017-02-25", "end_release_date" => "2017-03-25"}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      # Row count should not be any higher than the default amount: new invoice line should not have been included in the report.
      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 7
    end
  end

  describe "run_schedulable" do
    it "intializes the report class and runs it" do
      settings = {"email_to"=>["goofus@fakeemail.com"], "quarterly"=>true, "fiscal_day"=>35}

      current_fiscal_month = FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 2, start_date: Date.today - 5.days, end_date: Date.today + 25.days)
      current_fiscal_quarter_start_month = FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 1, start_date: current_fiscal_month.start_date - 30.days, end_date: current_fiscal_month.start_date - 1.day)
      prev_fiscal_quarter_end_month = FiscalMonth.create!(company_id: ascena.id, year: 2016, month_number: 12, start_date: current_fiscal_quarter_start_month.start_date - 30.days, end_date: current_fiscal_quarter_start_month.start_date - 1.day)
      prev_fiscal_quarter_start_month = FiscalMonth.create!(company_id: ascena.id, year: 2016, month_number: 10, start_date: prev_fiscal_quarter_end_month.start_date - 60.days, end_date: prev_fiscal_quarter_end_month.start_date - 31.day)

      expect_any_instance_of(subject).to receive(:run_report)
      m = double('mail')
      expect(OpenMailer).to receive(:send_simple_html).with(
          ["goofus@fakeemail.com"],
          "[VFI Track] Ascena Vendor Scorecard [Q4 2016]",
          "Attached is the Ascena Vendor Scorecard Report for Q4 2016, #{prev_fiscal_quarter_start_month.start_date.strftime("%m/%d/%Y")} - #{prev_fiscal_quarter_end_month.end_date.strftime("%m/%d/%Y")}.",
          # Temp file is evidently purged by the time this comparison is made.
          [nil]
      ).and_return(m)
      expect(m).to receive(:deliver!)

      subject.run_schedulable(settings)

      # Verify some settings values were populated by the scheduling method for report-running purposes.
      expect(settings['range_field']).to eq('first_release_date')
      expect(settings['start_release_date']).to eq(prev_fiscal_quarter_start_month.start_date)
      expect(settings['end_release_date']).to eq(prev_fiscal_quarter_end_month.end_date)
      expect(settings['file_name']).to eq("Ascena Vendor Scorecard [Q4 2016]")
    end

    it "does not run if the wrong fiscal day" do
      settings = {"email_to"=>["goofus@fakeemail.com"], "quarterly"=>true, "fiscal_day"=>4}

      # The current day is day 5 of the fiscal month, not day 4 (what the settings are looking for).
      current_fiscal_month = FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 1, start_date: Date.today - 5.days, end_date: Date.today + 25.days)

      expect_any_instance_of(subject).not_to receive(:run_report)
      expect(OpenMailer).not_to receive(:send_simple_html)

      subject.run_schedulable(settings)

      # Verify some settings values were not populated.
      expect(settings['range_field']).to eq(nil)
      expect(settings['start_release_date']).to eq(nil)
      expect(settings['end_release_date']).to eq(nil)
      expect(settings['file_name']).to eq(nil)
    end

    it "does not run if previous fiscal quarter info cannot be found" do
      settings = {"email_to"=>["goofus@fakeemail.com"], "quarterly"=>true, "fiscal_day"=>5}

      current_fiscal_month = FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 1, start_date: Date.today - 5.days, end_date: Date.today + 25.days)

      expect_any_instance_of(subject).not_to receive(:run_report)
      expect(OpenMailer).not_to receive(:send_simple_html)

      subject.run_schedulable(settings)

      # Verify some settings values were not populated.
      expect(settings['range_field']).to eq(nil)
      expect(settings['start_release_date']).to eq(nil)
      expect(settings['end_release_date']).to eq(nil)
      expect(settings['file_name']).to eq(nil)
    end
  end

end
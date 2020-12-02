describe OpenChain::CustomHandler::Ascena::AscenaVendorScorecardReport do

  subject { described_class }
    let! (:ascena) { with_customs_management_id(create(:importer, name: "Ascena", system_code: "ASCENA"), "ASCE") }

  describe "permission?" do
    # check that Ann is NOT included among the available customers
    let! (:ann) { with_customs_management_id(create(:importer, name: "Ann"), "ATAYLOR") }
    let! (:maurices) { with_customs_management_id(create(:importer, name: "Maurices"), "MAUR") }
    let! (:ascena_master) { with_customs_management_id(create(:importer, name: "Ascena Master"), "ASCENAMASTER") }
    let! (:user) { create(:master_user) }

    let!(:ms) do
      m = stub_master_setup
      allow(m).to receive(:custom_feature?).with("Ascena Reports").and_return true
      allow(user).to receive(:view_entries?).and_return true
      m
    end

    let!(:cust_descriptions) {[{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"},
                               {cust_num: "MAUR", sys_code: "MAUR", name: "MAURICES", short_name: "Maurices"}]}

    it "returns empty if 'Ascena Reports' custom feature absent" do
      allow(ms).to receive(:custom_feature?).with("Ascena Reports").and_return false
      expect(subject.permissions user).to be_empty
    end

    it "returns empty if user can't view entries" do
      allow(user).to receive(:view_entries?).and_return false
      expect(subject.permissions user).to be_empty
    end

    it "returns info for Ascena, Maurices if master user" do
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns info for Ascena, Maurices if user belongs to ASCENAMASTER" do
      user.company = ascena_master; user.company.save!
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns info for Ascena, Maurices if user belongs to ASCE_TRADE_ASSOC group" do
      user.company.update master: false
      g = create(:group, system_code: "ASCE_TRADE_ASSOC")
      user.groups << g
      expect(subject.permissions user).to eq(cust_descriptions)
    end

    it "returns only info for user's company if user doesn't belong to privileged category" do
      user.company = ascena; user.company.save!
      expect(subject.permissions user).to eq([{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"}])
    end

    it "omits info for missing company" do
      maurices.destroy
      expect(subject.permissions user).to eq([{cust_num: "ASCE", sys_code: "ASCENA", name: "ASCENA TRADE SERVICES LLC", short_name: "Ascena"}])
    end
  end

  def create_data
    e = create(:entry, importer: ascena, entry_number: "entry_no", customer_number: "ASCE", fiscal_date: Date.new(2017, 3, 1), first_release_date: DateTime.new(2017, 3, 1, 5, 0))

    inv = e.commercial_invoices.create! invoice_number: "INV"

    @line = inv.commercial_invoice_lines.create! po_number: "PO", contract_amount: 5.43, mid: "mid12345", value: 2.43, product_line: "prodlineA", part_number: "part_X"
    tariff1a = @line.commercial_invoice_tariffs.create! duty_rate: BigDecimal(".1")
    tariff1b = @line.commercial_invoice_tariffs.create! duty_rate: BigDecimal(".05")

    # No first sale claim on this line
    @line2 = inv.commercial_invoice_lines.create! po_number: "PO", contract_amount: 0, mid: @line.mid, value: 1.21, product_line: "prodlineA2", part_number: "part_X"
    tariff2 = @line2.commercial_invoice_tariffs.create! duty_rate: BigDecimal(".1")

    @line3 = inv.commercial_invoice_lines.create! po_number: "PO2", contract_amount: 1.56, mid: "mid23456", value: 3.45, product_line: "prodlineB", part_number: "part_Y"
    tariff3 = @line3.commercial_invoice_tariffs.create! duty_rate: BigDecimal(".1")

    @line4 = inv.commercial_invoice_lines.create! po_number: "PO3", contract_amount: 1.67, mid: "mid12345", value: 0.25, product_line: "prodlineC", part_number: "part_Z"
    tariff4 = @line4.commercial_invoice_tariffs.create! duty_rate: BigDecimal(".1")

    DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid12345-vendorId1", value: "2017-01-01")
    DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid12345-vendorId2", value: "2016-12-31")
    DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid23456-vendorId1", value: "2017-02-22")

    @vendor = create(:company, name: "Ascena Vendor", system_code:"vendorId1")
    @vendor2 = create(:company, name: "Ascena Vendor 2", system_code:"vendorId2")
    @factory = create(:company, name: "Crapco Industries")
    @factory2 = create(:company, name: "Carpco Deluxe Knock-offs")

    @order1A = create(:order, order_number: "ASCENA-prodlineA-PO", vendor: @vendor, factory: @factory)
    @order1B = create(:order, order_number: "ASCENA-prodlineA2-PO", vendor: @vendor, factory: @factory)
    @order2 = create(:order, order_number: "ASCENA-prodlineB-PO2", vendor: @vendor, factory: @factory2)
    @order3 = create(:order, order_number: "ASCENA-prodlineC-PO3", vendor: @vendor2, factory: @factory)

    e
  end

  # Purpose is to verify that different joins are made for Ascena and Maurices.
  describe "make_query" do
    context "Ascena" do
      let!(:entry) { create_data }

      it "returns expected results" do
        qry = subject.new.make_query "2017-02-25", "2017-03-25", "first_release_date", ["ASCE"]
        results = ActiveRecord::Base.connection.execute qry
        expect(results.count).to eq 4
        r = []
        results.each { |res| r << res }
        expect(r[0]).to eq ["Ascena Vendor", @vendor.id, "Carpco Deluxe Knock-offs", @factory2.id, "entry_no", "2017-02-22", DateTime.new(2017, 3, 1, 5, 0), "INV", 3.45, "prodlineB", "PO2", "part_Y", 1.56, 1.56, -0.19]
        expect(r[1]).to eq ["Ascena Vendor", @vendor.id, "Crapco Industries", @factory.id, "entry_no", "2017-01-01", DateTime.new(2017, 3, 1, 5, 0), "INV", 2.43, "prodlineA", "PO", "part_X", 5.43, 5.43, 0.45]
        expect(r[2]).to eq ["Ascena Vendor", @vendor.id, "Crapco Industries", @factory.id, "entry_no", "2017-01-01", DateTime.new(2017, 3, 1, 5, 0), "INV", 1.21, "prodlineA2", "PO", "part_X", 0.0, 1.21, 0.0]
        expect(r[3]).to eq ["Ascena Vendor 2", @vendor2.id, "Crapco Industries", @factory.id, "entry_no", "2016-12-31", DateTime.new(2017, 3, 1, 5, 0), "INV", 0.25, "prodlineC", "PO3", "part_Z", 1.67, 1.67, 0.14]
      end
    end

    context "Maurices" do
      let!(:entry) { create_data }

      it "returns expected results" do
        entry.update! customer_number: "MAUR"
        @line.update! po_number: "PO1"
        @line2.update! po_number: "PO2"
        @line3.update! po_number: "PO3"
        @line4.update! po_number: "PO4"
        @order1A.update! order_number: "ASCENA-MAU-PO1"
        @order1B.update! order_number: "ASCENA-MAU-PO2"
        @order2.update! order_number: "ASCENA-MAU-PO3"
        @order3.update! order_number: "ASCENA-MAU-PO4"
        qry = subject.new.make_query "2017-02-25", "2017-03-25", "first_release_date", ["MAUR"]

        results = ActiveRecord::Base.connection.execute qry
        expect(results.count).to eq 4
        r = []
        results.each { |res| r << res }
        expect(r[0]).to eq ["Ascena Vendor", @vendor.id, "Carpco Deluxe Knock-offs", @factory2.id, "entry_no", "2017-02-22", DateTime.new(2017, 3, 1, 5, 0), "INV", 3.45, "prodlineB", "PO3", "part_Y", 1.56, 1.56, -0.19]
        expect(r[1]).to eq ["Ascena Vendor", @vendor.id, "Crapco Industries", @factory.id, "entry_no", "2017-01-01", DateTime.new(2017, 3, 1, 5, 0), "INV", 2.43, "prodlineA", "PO1", "part_X", 5.43, 5.43, 0.45]
        expect(r[2]).to eq ["Ascena Vendor", @vendor.id, "Crapco Industries", @factory.id, "entry_no", "2017-01-01", DateTime.new(2017, 3, 1, 5, 0), "INV", 1.21, "prodlineA2", "PO2", "part_X", 0.0, 1.21, 0.0]
        expect(r[3]).to eq ["Ascena Vendor 2", @vendor2.id, "Crapco Industries", @factory.id, "entry_no", "2016-12-31", DateTime.new(2017, 3, 1, 5, 0), "INV", 0.25, "prodlineC", "PO4", "part_Z", 1.67, 1.67, 0.14]
      end
    end
  end

  describe "run_report" do

    let! (:entry) { create_data }

    it "runs release-date-based report" do
      tf = subject.run_report nil, {"range_field" => "first_release_date", "start_release_date" => "2017-02-25", "end_release_date" => "2017-03-25", "cust_numbers" => ["ASCE", "MAUR"]}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      expect(sheet = wb.worksheet("Vendor")).not_to be_nil
      expect(sheet.rows.count).to eq 6
      expect(sheet.row(0)).to eq ["<Summary by vendor>", nil, nil, nil, nil, nil]
      expect(sheet.row(2)).to eq ["No.", "VENDOR", "SUM OF INV AMOUNT", "SUM OF FS INV AMOUNT", "SUM OF SAVINGS", "PENETRATION"]
      expect(sheet.row(3)).to eq [1, "Ascena Vendor", 8.2, 6.99, 0.26, 0.85]
      expect(sheet.row(4)).to eq [2, "Ascena Vendor 2", 1.67, 1.67, 0.14, 1]
      expect(sheet.row(5)).to eq [nil, "TOTAL", 9.87, 8.66, 0.4, 0.88]

      expect(sheet = wb.worksheet("Vendor create Pair")).not_to be_nil
      expect(sheet.rows.count).to eq 7
      expect(sheet.row(0)).to eq ["<Summary by vendor / factory pair>", nil, nil, nil, nil, nil, nil]
      expect(sheet.row(2)).to eq ["No.", "VENDOR", "FACTORY", "SUM OF INV AMOUNT", "SUM OF FS INV AMOUNT", "SUM OF SAVINGS", "REMARKS"]
      expect(sheet.row(3)).to eq [1, "Ascena Vendor", "Carpco Deluxe Knock-offs", 1.56, 1.56, -0.19, "Eligible - 02/22/2017"]
      expect(sheet.row(4)).to eq [2, "Ascena Vendor", "Crapco Industries", 6.64, 5.43, 0.45, "Eligible < 2017"]
      expect(sheet.row(5)).to eq [3, "Ascena Vendor 2", "Crapco Industries", 1.67, 1.67, 0.14, "Eligible - 12/31/2016"]
      expect(sheet.row(6)).to eq [nil, "TOTAL", nil, 9.87, 8.66, 0.4, nil]

      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 7
      expect(sheet.row(0)).to eq ["<Detailed Data Lines>", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(2)).to eq ["No.", "VENDOR", "FACTORY", "ENTRY NUMBER", "INV AMOUNT", "FS SAVINGS", "FIRST RELEASE DATE", "INVOICE NUMBER", "VALUE", "PRODUCT LINE", "PO NUMBER", "PART NUMBER", "CONTRACT AMOUNT", "REMARKS"]
      expect(sheet.row(3)).to eq [1, "Ascena Vendor", "Carpco Deluxe Knock-offs", "entry_no", 1.56, -0.19, "03/01/2017", "INV", 3.45, "prodlineB", "PO2", "part_Y", 1.56, "Eligible - 02/22/2017"]
      expect(sheet.row(4)).to eq [2, "Ascena Vendor", "Crapco Industries", "entry_no", 5.43, 0.45, "03/01/2017", "INV", 2.43, "prodlineA", "PO", "part_X", 5.43, "Eligible < 2017"]
      expect(sheet.row(5)).to eq [3, "Ascena Vendor", "Crapco Industries", "entry_no", 1.21, 0.0, "03/01/2017", "INV", 1.21, "prodlineA2", "PO", "part_X", 0, "Eligible < 2017"]
      expect(sheet.row(6)).to eq [4, "Ascena Vendor 2", "Crapco Industries", "entry_no", 1.67, 0.14, "03/01/2017", "INV", 0.25, "prodlineC", "PO3", "part_Z", 1.67, "Eligible - 12/31/2016"]
    end

    it "runs fiscal-date-based report" do
      fiscal_month_1 = FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 1, start_date: "2017-02-25")
      fiscal_month_2 = FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 2, start_date: "2017-03-25")

      tf = subject.run_report nil, {"range_field" => "fiscal_date", "start_fiscal_year_month" => "2017-1", "end_fiscal_year_month" => "2017-2", "cust_numbers" => ["ASCE", "MAUR"]}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      expect(sheet = wb.worksheet("Vendor")).not_to be_nil
      expect(sheet.rows.count).to eq 6

      expect(sheet = wb.worksheet("Vendor create Pair")).not_to be_nil
      expect(sheet.rows.count).to eq 7

      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 7
    end

    it "ignores invoice content with no MID/vendor system code cross reference" do
      inv2 = entry.commercial_invoices.create! invoice_number: "INV2"
      line_bad = inv2.commercial_invoice_lines.create! po_number: "PO_bad", contract_amount: 5.43, mid: "mid_bogus", value: 2.43, product_line: "prodlineA", part_number: "part_X"
      tariff_bad = line_bad.commercial_invoice_tariffs.create! entered_value: BigDecimal("10"), duty_amount: BigDecimal("1")
      vendor_bad = create(:company, name: "Bad Ascena Vendor", system_code: "vendorId3")
      factory_bad = create(:company, name: "Chemco Industries")
      order_bad = create(:order, order_number: "ASCENA-prodlineA-PO_bad", vendor: vendor_bad, factory: factory_bad)

      tf = subject.run_report nil, {"range_field" => "first_release_date", "start_release_date" => "2017-02-25", "end_release_date" => "2017-03-25", "cust_numbers" => ["ASCE", "MAUR"]}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      # Row count should not be any higher than the default amount: new invoice line should not have been included in the report.
      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 7
    end

    it "ignores invoice content attached MID/vendor system code cross reference with invalid date" do
      inv2 = entry.commercial_invoices.create! invoice_number: "INV2"
      line_bad = inv2.commercial_invoice_lines.create! po_number: "PO_bad", contract_amount: 5.43, mid: "mid_bogus", value: 2.43, product_line: "prodlineA", part_number: "part_X"
      tariff_bad = line_bad.commercial_invoice_tariffs.create! entered_value: BigDecimal("10"), duty_amount: BigDecimal("1")
      vendor_bad = create(:company, name: "Bad Ascena Vendor", system_code: "vendorId3")
      factory_bad = create(:company, name: "Chemco Industries")
      order_bad = create(:order, order_number: "ASCENA-prodlineA-PO_bad", vendor: vendor_bad, factory: factory_bad)

      DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid_bogus-vendorId3", value: "invalid")

      tf = subject.run_report nil, {"range_field" => "first_release_date", "start_release_date" => "2017-02-25", "end_release_date" => "2017-03-25", "cust_numbers" => ["ASCE", "MAUR"]}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      # Row count should not be any higher than the default amount: new invoice line should not have been included in the report.
      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 7
    end

    it "ignores invoice content with MID/vendor system code cross reference matching only vendor system code" do
      inv2 = entry.commercial_invoices.create! invoice_number: "INV2"
      line_bad = inv2.commercial_invoice_lines.create! po_number: "PO_bad", contract_amount: 5.43, mid: "mid_bogus", value: 2.43, product_line: "prodlineA", part_number: "part_X"
      tariff_bad = line_bad.commercial_invoice_tariffs.create! entered_value: BigDecimal("10"), duty_amount: BigDecimal("1")
      vendor_bad = create(:company, name: "Bad Ascena Vendor", system_code: "vendorId3")
      factory_bad = create(:company, name: "Chemco Industries")
      order_bad = create(:order, order_number: "ASCENA-prodlineA-PO_bad", vendor: vendor_bad, factory: factory_bad)

      DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid_mismatch-vendorId3", value: "2017-02-22")

      tf = subject.run_report nil, {"range_field" => "first_release_date", "start_release_date" => "2017-02-25", "end_release_date" => "2017-03-25", "cust_numbers" => ["ASCE", "MAUR"]}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      # Row count should not be any higher than the default amount: new invoice line should not have been included in the report.
      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 7
    end

    it "ignores invoice content with MID/vendor system code cross reference matching only MID" do
      inv2 = entry.commercial_invoices.create! invoice_number: "INV2"
      line_bad = inv2.commercial_invoice_lines.create! po_number: "PO_bad", contract_amount: 5.43, mid: "mid_bogus", value: 2.43, product_line: "prodlineA", part_number: "part_X"
      tariff_bad = line_bad.commercial_invoice_tariffs.create! entered_value: BigDecimal("10"), duty_amount: BigDecimal("1")
      vendor_bad = create(:company, name: "Bad Ascena Vendor", system_code: "vendorId3")
      factory_bad = create(:company, name: "Chemco Industries")
      order_bad = create(:order, order_number: "ASCENA-prodlineA-PO_bad", vendor: vendor_bad, factory: factory_bad)

      DataCrossReference.create!(cross_reference_type: "asce_mid", key: "mid_bogus-vendor_system_code_mismatch", value: "2017-02-22")

      tf = subject.run_report nil, {"range_field" => "first_release_date", "start_release_date" => "2017-02-25", "end_release_date" => "2017-03-25", "cust_numbers" => ["ASCE", "MAUR"]}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      # Row count should not be any higher than the default amount: new invoice line should not have been included in the report.
      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 7
    end
  end

  describe "run_schedulable" do
    it "intializes the report class and runs it" do
      settings = {"email_to"=>["goofus@fakeemail.com"], "quarterly"=>true, "fiscal_day"=>36, "cust_numbers" => ["ASCE", "MAUR"]}

      Timecop.freeze(ActiveSupport::TimeZone["America/New_York"].parse("2017-04-05").in_time_zone("UTC")) do
        # Current fiscal month, which is the second month of the quarter.
        FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 2, start_date: Date.new(2017, 4, 1), end_date: Date.new(2017, 4, 30))
        # First month of the current quarter.
        FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 1, start_date: Date.new(2017, 3, 1), end_date: Date.new(2017, 3, 31))
        # Last month of the previous quarter.
        FiscalMonth.create!(company_id: ascena.id, year: 2016, month_number: 12, start_date: Date.new(2017, 2, 1), end_date: Date.new(2017, 2, 28))
        # First month of the previous quarter.
        FiscalMonth.create!(company_id: ascena.id, year: 2016, month_number: 10, start_date: Date.new(2016, 12, 1), end_date: Date.new(2016, 12, 31))

        expect_any_instance_of(subject).to receive(:run_scorecard_report)
        m = double('mail')
        expect(OpenMailer).to receive(:send_simple_html).with(
            ["goofus@fakeemail.com"],
            "[VFI Track] Ascena-Maurices Vendor Scorecard [Q4 2016]",
            "Attached is the Ascena-Maurices Vendor Scorecard Report for Q4 2016, 12/01/2016 - 02/28/2017.",
            # Temp file is evidently purged by the time this comparison is made.
            [nil]
        ).and_return(m)
        expect(m).to receive(:deliver_now)

        subject.run_schedulable(settings)

        # Verify some settings values were populated by the scheduling method for report-running purposes.
        expect(settings['range_field']).to eq('first_release_date')
        expect(settings['start_release_date']).to eq(Date.new(2016, 12, 1))
        expect(settings['end_release_date']).to eq(Date.new(2017, 2, 28))
        expect(settings['file_name']).to eq("Ascena-Maurices Vendor Scorecard [Q4 2016]")
      end
    end

    it "does not run if the wrong fiscal day" do
      settings = {"email_to"=>["goofus@fakeemail.com"], "quarterly"=>true, "fiscal_day"=>4, "cust_numbers" => ["ASCE", "MAUR"]}

      Timecop.freeze(ActiveSupport::TimeZone["America/New_York"].parse("2017-04-05").in_time_zone("UTC")) do
        # The current day is day 5 of the fiscal month, not day 4 (what the settings are looking for).
        FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 1, start_date: Date.new(2017, 4, 1), end_date: Date.new(2017, 4, 30))

        expect(subject).not_to receive(:run_report)
        expect(OpenMailer).not_to receive(:send_simple_html)

        subject.run_schedulable(settings)

        # Verify some settings values were not populated.
        expect(settings['range_field']).to eq(nil)
        expect(settings['start_release_date']).to eq(nil)
        expect(settings['end_release_date']).to eq(nil)
        expect(settings['file_name']).to eq(nil)
      end
    end

    it "does not run if previous fiscal quarter info cannot be found" do
      settings = {"email_to"=>["goofus@fakeemail.com"], "quarterly"=>true, "fiscal_day"=>5, "cust_numbers" => ["ASCE", "MAUR"]}

      Timecop.freeze(ActiveSupport::TimeZone["America/New_York"].parse("2017-04-05").in_time_zone("UTC")) do
        # Current quarter.
        FiscalMonth.create!(company_id: ascena.id, year: 2017, month_number: 1, start_date: Date.new(2017, 4, 1), end_date: Date.new(2017, 4, 30))
        # There is no info on file for previous quarter.

        expect(subject).not_to receive(:run_report)
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

end

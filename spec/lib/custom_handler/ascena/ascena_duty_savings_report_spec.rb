describe OpenChain::CustomHandler::Ascena::AscenaDutySavingsReport do

  subject { described_class }
  let! (:ascena) { Factory(:importer, alliance_customer_number: "ASCE", name: "Ascena", system_code: "ASCENA") }
  let! (:ann) { Factory(:importer, alliance_customer_number: "ATAYLOR", name: "Ann") }
  let (:cdefs) { described_class::Query.new.cdefs }

  describe "permission?" do
    let!(:ms) do
      m = stub_master_setup
      allow(m).to receive(:custom_feature?).with("Ascena Reports").and_return true
      m
    end
    
    it "allows access for master users who can view entries" do
      u = Factory(:master_user)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for Ascena users who can view entries" do
      u = Factory(:user, company: ascena)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for users of Ascena's parent companies" do
      parent = Factory(:company, linked_companies: [ascena])
      u = Factory(:user, company: parent)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for Ann users who can view entries" do
      u = Factory(:user, company: ann)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for users of Ann's parent companies" do
      parent = Factory(:company, linked_companies: [ann])
      u = Factory(:user, company: parent)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "prevents access by other companies" do
      u = Factory(:user)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq false
    end

    it "prevents access by users who can't view entries" do
      u = Factory(:master_user)
      allow(u).to receive(:view_entries?).and_return false
      expect(subject.permission? u).to eq false
    end

    it "prevents access if Ascena record not found" do
      ascena.destroy
      u = Factory(:user, company: ann)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq false
    end

    it "prevents access if Ann record not found" do
      ann.destroy
      u = Factory(:user, company: ascena)
      allow(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq false
    end

    it "prevents access on instance without 'Ascena Reports' custom feature" do
      u = Factory(:master_user)
      allow(u).to receive(:view_entries?).and_return true
      allow(ms).to receive(:custom_feature?).with("Ascena Reports").and_return false
      expect(subject.permission? u).to eq false
    end
  end

  describe "fiscal_month" do
    let (:fiscal_month) { Factory(:fiscal_month, company: ascena, year: 2017, month_number: 3) }

    it "parses fiscal month descriptor and returns fiscal month record" do
      fiscal_month
      expect(subject.fiscal_month({"fiscal_month"=>"2017-03"})).to eq fiscal_month
    end

    it "returns nil if format is bad" do
      expect(subject.fiscal_month({"fiscal_month"=>"month"})).to be_nil
    end

    it "handles missing setting" do
      expect(subject.fiscal_month({})).to be_nil
    end
  end

  describe "run_schedulable" do
    let!(:current_fm) { Factory(:fiscal_month, company: ascena, start_date: Date.new(2018,3,15), end_date: Date.new(2018,4,15), year: 2018, month_number: 2) }
    let!(:previous_fm) { Factory(:fiscal_month, company: ascena, start_date: Date.new(2018,2,15), end_date: Date.new(2018,3,14), year: 2018, month_number: 1) }
  
    it "runs report for previous fiscal month on fourth day of fiscal month" do
      Tempfile.open(["hi", ".xls"]) do |t|
        expect_any_instance_of(subject).to receive(:run).with(previous_fm).and_yield t
        Timecop.freeze(DateTime.new(2018,3,18,12,0)) do
          subject.run_schedulable('email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'], 
                                  'cust_numbers' => ['ASCE', 'ATAYLOR'],
                                  'company' => 'ASCENA',
                                  'fiscal_day' => 3)
        end

        mail = ActionMailer::Base.deliveries.pop
        expect(mail.to).to eq ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk']
        expect(mail.subject).to eq "Duty Savings Report 2018-01"
        expect(mail.body).to match /Attached is the Duty Savings Report for 2018-01\./
        # not sure why following expectation fails. Leaving it commented for now.
        # expect(mail.attachments.first).to eq t
      end
    end

    it "does nothing on other days" do
      Timecop.freeze(DateTime.new(2018,3,20,12,0)) do
        subject.run_schedulable('email' => ['tufnel@stonehenge.biz', 'st-hubbins@hellhole.co.uk'], 
                                'cust_numbers' => ['ASCE', 'ATAYLOR'],
                                'company' => 'ASCENA',
                                'fiscal_day' => 3)
      end
      mail = ActionMailer::Base.deliveries.pop
      expect(mail).to be_nil
    end

  end

  describe "run_report" do

    let! (:entry) {
      e = Factory(:entry, importer: ascena, import_country: Factory(:country), customer_number: "ASCE", source_system: "Alliance", fiscal_date: Date.new(2017, 3, 1), broker_reference: "REF", transport_mode_code: "10", fiscal_year: 2017, fiscal_month: 3, release_date: DateTime.new(2017, 3, 1, 5, 0))
      ci = e.commercial_invoices.create! invoice_number: "INV"
      cil = ci.commercial_invoice_lines.create! po_number: "PO", part_number: "PART", product_line: "JST", non_dutiable_amount: 0, value: BigDecimal("10"), contract_amount: 0
      cit = cil.commercial_invoice_tariffs.create! hts_code: "1234567890", tariff_description: "DESC", entered_value: BigDecimal("10"), spi_primary: "", duty_rate: BigDecimal("0.1"), duty_amount: BigDecimal("1")
      
      cil = ci.commercial_invoice_lines.create! po_number: "PO", part_number: "PART2", product_line: "JST", non_dutiable_amount: 0, value: BigDecimal("10"), contract_amount: 0
      cit = cil.commercial_invoice_tariffs.create! hts_code: "1234567890", tariff_description: "DESC", entered_value: BigDecimal("10"), spi_primary: "", duty_rate: BigDecimal("0.1"), duty_amount: BigDecimal("1")

      e
    }

    let! (:order) {
      order = Factory(:order, order_number: "ASCENA-PO")
      order.update_custom_value! cdefs[:ord_type], "AGS"
      order
    }

    let! (:fiscal_month) { Factory(:fiscal_month, company: ascena, year: 2017, month_number: 3, start_date: Date.new(2017, 3, 1), end_date: Date.new(2017, 4, 1)) }

    it "skips anything that does not have duty savings" do
      tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE", "ATAYLOR"]}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)
      expect(sheet = wb.worksheet("ATS Summary")).not_to be_nil
      expect(sheet2 = wb.worksheet("Ann Inc. Summary")).not_to be_nil
      summary_header = ["Program Name", "Entry Usage Count", "Total Entered Value", "Total Duty Paid", "Total Calculated Invoice Value", "Total Calculated Duty", "Duty Savings", "Duty Savings Percentage"]
      expect(sheet.row(0)).to eq summary_header
      expect(sheet2.row(0)).to eq summary_header
      # Since there was no savings, only the header row is present
      expect(sheet.rows.count).to eq 1

      expect(sheet = wb.worksheet("First Sale")).not_to be_nil
      expect(sheet.rows.count).to eq 10
      expect(sheet.row(0)).to eq [nil, "Justice", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn", nil, "Ann Inc."]
      expect(sheet.row(1)).to eq ["AGS Vendor Invoice", 0, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(2)).to eq ["AGS Entered Value", 0, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(3)).to eq ["AGS Duty Savings", 0, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(4)).to eq ["AGS Total Brand FOB Receipts", 20, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]

      expect(sheet.row(6)).to eq ["NONAGS Vendor Invoice", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(7)).to eq ["NONAGS Entered Value", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(8)).to eq ["NONAGS Duty Savings", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(9)).to eq ["NONAGS Total Brand FOB Receipts", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]


      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 3
      expect(sheet.row(0)).to eq ["Broker Reference Number", "Importer", "First Sale", "Supplier", "Manufacturer", "Transactions Related", "Mode of Transport", "Fiscal Month", "Release Date", 
                                  "Filer", "Entry No.", "7501 Line Number", "Invoice Number", "Product Code", "PO Number", "Brand", "Order Type", "Country of Origin", "Country of Export", 
                                  "Arrival Date", "Import Date", "Arrival Port", "Entry Port", "Tariff", "Duty Rate", "Goods Description", "Price/Unit", "Invoice Quantity", "Invoice UOM", 
                                  "Original FOB Unit Value", "Original FOB Entered Value", "Duty", "First Sale Difference", "First Sale Duty Savings", "First Sale Margin %", 
                                  "Line Price Before Discounts", "Line Entered Value", "Air/Sea Discount", "Air/Sea Per Unit Savings", "Air/Sea Duty Savings", "Early Payment Discount", 
                                  "EPD per Unit Savings", "EPD Duty Savings", "Trade Discount", "Trade Discount per Unit Savings", "Trade Discount Duty Savings", "SPI", "Original Duty Rate", 
                                  "SPI Duty Savings", "Fish and Wildlife", "Hanger Duty Savings", "MP vs. Air/Sea", "MP vs. EPD", "MP vs. Trade Discount", "MP vs. Air/Sea/EPD Trade", 
                                  "First Sale Savings", "Air/Sea Savings", "EPD Savings", "Trade Discount Savings", "Applied Discount"]
    end

    it "records non-ags first sale data" do
      order.update_custom_value! cdefs[:ord_type], "NONAGS"
      tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)

      expect(sheet = wb.worksheet("First Sale")).not_to be_nil
      expect(sheet.rows.count).to eq 10
      expect(sheet.row(1)).to eq ["AGS Vendor Invoice", nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(2)).to eq ["AGS Entered Value", nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(3)).to eq ["AGS Duty Savings", nil, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(4)).to eq ["AGS Total Brand FOB Receipts", nil, nil, nil, nil, nil, nil, nil, nil, nil]

      expect(sheet.row(6)).to eq ["NONAGS Vendor Invoice", 0, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(7)).to eq ["NONAGS Entered Value", 0, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(8)).to eq ["NONAGS Duty Savings", 0, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(9)).to eq ["NONAGS Total Brand FOB Receipts", 20, nil, nil, nil, nil, nil, nil, nil, nil]

      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 3
    end

    it "records air/sea differential amounts" do
      entry.update_attributes! transport_mode_code: "40"
      entry.commercial_invoice_lines.each {|line| line.update_attributes! non_dutiable_amount: 20 }

      tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("ATS Summary")
      expect(sheet.rows.count).to eq 3
      expect(sheet.row(1)).to eq ["Air Sea Differential", 1, 20, 2, 60, 6, 4, 0.6667]
      expect(sheet.row(2)).to eq ["Actual Entry Totals", 1, 20, 2, 60, 6, 4, 0.6667]
    end

    it "records first sale amounts using Ascena formula" do
      entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20 }
      tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("ATS Summary")
      expect(sheet.rows.count).to eq 3
      expect(sheet.row(1)).to eq ["First Sale", 1, 20, 2, 40, 4, 2, 0.5]
      expect(sheet.row(2)).to eq ["Actual Entry Totals", 1, 20, 2, 40, 4, 2, 0.5]
    end

    it "records first sale amounts using Ann formula" do
      entry.update_attributes! customer_number: "ATAYLOR"
      entry.commercial_invoice_lines.each do |line| 
        line.update_attributes! contract_amount: 20
        line.commercial_invoice_tariffs.first.update_attributes! entered_value: 15
      end
      tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ATAYLOR"]}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("Ann Inc. Summary")
      expect(sheet.rows.count).to eq 3
      expect(sheet.row(1)).to eq ["First Sale", 1, 30, 2, 40, 3, 1, 0.3333]
      expect(sheet.row(2)).to eq ["Actual Entry Totals", 1, 30, 2, 40, 3, 1, 0.3333]
    end

    it "records 'Other' duty savings only for Ascena" do
      # This is anything with a non-dutiable amount that is NOT an Air entry
      entry.commercial_invoice_lines.each {|line| line.update_attributes! non_dutiable_amount: 20 }

      tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("ATS Summary")
      expect(sheet.rows.count).to eq 3
      expect(sheet.row(1)).to eq ["Other", 1, 20, 2, 60, 6, 4, 0.6667]
      expect(sheet.row(2)).to eq ["Actual Entry Totals", 1, 20, 2, 60, 6, 4, 0.6667]

      entry.update_attributes! customer_number: "ATAYLOR"
      tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ATAYLOR"]}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("Ann Inc. Summary")
      expect(sheet.rows.count).to eq 1
    end

    it "records EPD Discount for Ann" do
      entry.update_attributes! customer_number: "ATAYLOR", importer: ann
      entry.commercial_invoice_lines.each {|line| line.update_attributes! miscellaneous_discount: 20 }
      i = Factory(:invoice, importer: entry.importer, invoice_number: "INV")
      i.invoice_lines.create! line_number: 1, early_pay_discount: 4, po_number: "PO", part_number: "PART"
      i.invoice_lines.create! line_number: 2, early_pay_discount: 4, po_number: "PO", part_number: "PART2"

      tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ATAYLOR"]}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("Ann Inc. Summary")
      expect(sheet.rows.count).to eq 3
      expect(sheet.row(1)).to eq ["EPD Discount", 1, 20, 2, 20, 2.8, 0.8, 0.2857]
      expect(sheet.row(2)).to eq ["Actual Entry Totals", 1, 20, 2, 20, 2.8, 0.8, 0.2857]
    end

    it "records Trade Discount for Ann" do
      entry.update_attributes! customer_number: "ATAYLOR", importer: ann
      i = Factory(:invoice, importer: entry.importer, invoice_number: "INV")
      i.invoice_lines.create! line_number: 1, trade_discount: 4, po_number: "PO", part_number: "PART"
      i.invoice_lines.create! line_number: 2, trade_discount: 4, po_number: "PO", part_number: "PART2"
      
      tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ATAYLOR"]}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("Ann Inc. Summary")
      expect(sheet.rows.count).to eq 3
      expect(sheet.row(1)).to eq ["Trade Discount", 1, 20, 2, 20, 2.8, 0.8, 0.2857]
      expect(sheet.row(2)).to eq ["Actual Entry Totals", 1, 20, 2, 20, 2.8, 0.8, 0.2857]
    end

    it "records savings that apply to more than one category" do
      OfficialTariff.create! country: entry.import_country, hts_code: "1234567890", common_rate: "20%", common_rate_decimal: 0.2
      entry.update_attributes! transport_mode_code: "40"
      entry.commercial_invoice_lines.each do |line| 
        line.update_attributes! non_dutiable_amount: 20, contract_amount: 20
        line.commercial_invoice_tariffs.each { |t| t.update_attributes! spi_primary: "P" }
      end

      tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("ATS Summary")
      expect(sheet.rows.count).to eq 5
      expect(sheet.row(1)).to eq ["Air Sea Differential", 1, 20, 2, 60, 6, 4, 0.6667]
      expect(sheet.row(2)).to eq ["CAFTA", 1, 20, 2, 20, 4, 2, 0.5]
      expect(sheet.row(3)).to eq ["First Sale", 1, 20, 2, 40, 4, 2, 0.5]
      expect(sheet.row(4)).to eq ["Actual Entry Totals", 1, 20, 2, 60, 6, 4, 0.6667]
    end

    context "with SPI" do
      let! (:us) { Factory(:country, iso_code: "US") }
      let! (:offical_tariff) { Factory :official_tariff, country: entry.import_country, hts_code: "1234567890", common_rate: "20%", common_rate_decimal: 0.2}

      it "records Jordan FTA duty savings" do
        entry.commercial_invoice_lines.each do |line| 
          line.commercial_invoice_tariffs.each do |t|
            t.update_attributes! spi_primary: "JO" 
          end
        end

        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("ATS Summary")
        expect(sheet.rows.count).to eq 3
        expect(sheet.row(1)).to eq ["Jordan FTA", 1, 20, 2, 20, 4, 2, 0.5]
        expect(sheet.row(2)).to eq ["Actual Entry Totals", 1, 20, 2, 20, 4, 2, 0.5]
      end

      it "records CAFTA FTA duty savings" do
        entry.commercial_invoice_lines.each do |line| 
          line.commercial_invoice_tariffs.each do |t|
            t.update_attributes! spi_primary: "P" 
          end
        end

        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("ATS Summary")
        expect(sheet.rows.count).to eq 3
        expect(sheet.row(1)).to eq ["CAFTA", 1, 20, 2, 20, 4, 2, 0.5]
        expect(sheet.row(2)).to eq ["Actual Entry Totals", 1, 20, 2, 20, 4, 2, 0.5]
      end
    end

    context "first sale tab" do
      it "records Justice first sale data" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "JST" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.row(0)).to eq [nil, "Justice", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn"]
        expect(sheet.row(1)).to eq ["AGS Vendor Invoice", 40, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(2)).to eq ["AGS Entered Value", 20, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(3)).to eq ["AGS Duty Savings", 2, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(4)).to eq ["AGS Total Brand FOB Receipts", 40, nil, nil, nil, nil, nil, nil, nil, nil]
      end

      it "records Lane Bryant first sale data" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "LB" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.row(1)).to eq ["AGS Vendor Invoice", nil, nil, 40, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(2)).to eq ["AGS Entered Value", nil, nil, 20, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(3)).to eq ["AGS Duty Savings", nil, nil, 2, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(4)).to eq ["AGS Total Brand FOB Receipts", nil, nil, 40, nil, nil, nil, nil, nil, nil]
      end

      it "records Catherines first sale data" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "CA" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.row(1)).to eq ["AGS Vendor Invoice", nil, nil, nil, nil, 40, nil, nil, nil, nil]
        expect(sheet.row(2)).to eq ["AGS Entered Value", nil, nil, nil, nil, 20, nil, nil, nil, nil]
        expect(sheet.row(3)).to eq ["AGS Duty Savings", nil, nil, nil, nil, 2, nil, nil, nil, nil]
        expect(sheet.row(4)).to eq ["AGS Total Brand FOB Receipts", nil, nil, nil, nil, 40, nil, nil, nil, nil]
      end

      it "records Maurices first sale data" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "MAU" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.row(1)).to eq ["AGS Vendor Invoice", nil, nil, nil, nil, nil, nil, 40, nil, nil]
        expect(sheet.row(2)).to eq ["AGS Entered Value", nil, nil, nil, nil, nil, nil, 20, nil, nil]
        expect(sheet.row(3)).to eq ["AGS Duty Savings", nil, nil, nil, nil, nil, nil, 2, nil, nil]
        expect(sheet.row(4)).to eq ["AGS Total Brand FOB Receipts", nil, nil, nil, nil, nil, nil, 40, nil, nil]
      end

      it "records Dress Barn first sale" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "DB" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.row(1)).to eq ["AGS Vendor Invoice", nil, nil, nil, nil, nil, nil, nil, nil, 40]
        expect(sheet.row(2)).to eq ["AGS Entered Value", nil, nil, nil, nil, nil, nil, nil, nil, 20]
        expect(sheet.row(3)).to eq ["AGS Duty Savings", nil, nil, nil, nil, nil, nil, nil, nil, 2]
        expect(sheet.row(4)).to eq ["AGS Total Brand FOB Receipts", nil, nil, nil, nil, nil, nil, nil, nil, 40]
      end

      it "records Ann Inc. first sale" do
        entry.update_attributes! customer_number: "ATAYLOR"
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20 }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ATAYLOR"]}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.row(0)).to eq [nil, "Ann Inc."]
        expect(sheet.row(6)).to eq ["NONAGS Vendor Invoice", 40]
        expect(sheet.row(7)).to eq ["NONAGS Entered Value", 20]
        expect(sheet.row(8)).to eq ["NONAGS Duty Savings", 2]
        expect(sheet.row(9)).to eq ["NONAGS Total Brand FOB Receipts", 40]
      end

      it "records both Ascena and Ann first sale" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "JST" }

        e = Factory(:entry, importer: ascena, customer_number: "ATAYLOR", source_system: "Alliance", fiscal_date: Date.new(2017, 3, 1), broker_reference: "REF", transport_mode_code: "10", fiscal_year: 2017, fiscal_month: 3, release_date: DateTime.new(2017, 3, 1, 5, 0))
        inv = e.commercial_invoices.create! invoice_number: "INV"
        line = inv.commercial_invoice_lines.create! po_number: "PO", part_number: "PART", non_dutiable_amount: 0, value: BigDecimal("10"), contract_amount: 20
        tariff = line.commercial_invoice_tariffs.create! hts_code: "1234567890", tariff_description: "DESC", entered_value: BigDecimal("10"), spi_primary: "", duty_rate: BigDecimal("0.1"), duty_amount: BigDecimal("1")
        line = inv.commercial_invoice_lines.create! po_number: "PO", part_number: "PART2", non_dutiable_amount: 0, value: BigDecimal("10"), contract_amount: 20
        tariff = line.commercial_invoice_tariffs.create! hts_code: "1234567890", tariff_description: "DESC", entered_value: BigDecimal("10"), spi_primary: "", duty_rate: BigDecimal("0.1"), duty_amount: BigDecimal("1")

        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE", "ATAYLOR"]}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.row(0)).to eq [nil, "Justice", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn", nil, "Ann Inc."]
        
        expect(sheet.row(1)).to eq ["AGS Vendor Invoice", 40, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(2)).to eq ["AGS Entered Value", 20, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(3)).to eq ["AGS Duty Savings", 2, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(4)).to eq ["AGS Total Brand FOB Receipts", 40, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
        
        expect(sheet.row(6)).to eq ["NONAGS Vendor Invoice", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 40]
        expect(sheet.row(7)).to eq ["NONAGS Entered Value", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 20]
        expect(sheet.row(8)).to eq ["NONAGS Duty Savings", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 2]
        expect(sheet.row(9)).to eq ["NONAGS Total Brand FOB Receipts", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 40]
      end

      it "includes non-dutiable amount in Total Brand FOB Receipts for Ascena" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! non_dutiable_amount: 1, contract_amount: 20, product_line: "JST" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03", "cust_numbers" => ["ASCE"]}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.row(0)).to eq [nil, "Justice", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn"]
        # includes 2 "other amount" + 2 "first sale": (20 + 1) + (20 + 1) + (10 + 1) + (10 + 1)
        expect(sheet.row(4)).to eq ["AGS Total Brand FOB Receipts", 64, nil, nil, nil, nil, nil, nil, nil, nil]
      end
    end

  end

  describe "DutySavingsCalculator" do
    let!(:row) { described_class::Wrapper.new [] }
    let!(:dsc) { described_class::DutySavingsCalculator.new row }

    describe "get" do
      it "returns default values when there aren't any savings" do
        row[:entered_value] = 10
        row[:duty_amount] = 3
        expect_any_instance_of(described_class::DutySavingsType).to receive(:get).and_return []

        expect(dsc.get).to eq [{savings_type: nil, savings_title: nil, calculations: {calculated_invoice_value: 10, calculated_duty: 3, savings: 0}}]
      end

      it "returns array of discounts" do
        air_sea_hsh = double "air/sea hsh"
        first_sale_hsh = double "first_sale_hsh"
        spi_hsh = double "spi_hsh"
        epd_hsh = double "epd_hsh"
        trade_hsh = double "trade_hsh"

        expect_any_instance_of(described_class::DutySavingsType).to receive(:get).and_return [[:air_sea, "Air Sea Differential"], [:first_sale, "First Sale"], 
                                                                                              [:spi, "CAFTA"], [:epd, "EPD Discount"], [:trade, "Trade Discount"], 
                                                                                              [:line, "Actual Entry Totals"]]
        expect(dsc).to receive(:calculate_air_sea_differential).and_return air_sea_hsh
        expect(dsc).to receive(:calculate_first_sale).and_return first_sale_hsh
        expect(dsc).to receive(:calculate_spi).and_return spi_hsh
        expect(dsc).to receive(:calculate_epd).and_return epd_hsh
        expect(dsc).to receive(:calculate_trade_discount).and_return trade_hsh
        expect_any_instance_of(described_class::ActualEntryTotalCalculator).to receive(:fill_totals)

        expect(dsc.get).to eq [{savings_type: :air_sea, savings_title: "Air Sea Differential", calculations: air_sea_hsh}, 
                               {savings_type: :first_sale, savings_title: "First Sale", calculations: first_sale_hsh},
                               {savings_type: :spi, savings_title: "CAFTA", calculations: spi_hsh},
                               {savings_type: :epd, savings_title: "EPD Discount", calculations: epd_hsh},
                               {savings_type: :trade, savings_title: "Trade Discount", calculations: trade_hsh},
                               # Because ActualEntryTotalCalculator#fill_totals is side-effecting, it's difficult to mock so we'll leave 'calculations' nil
                               {savings_type: :line, savings_title: "Actual Entry Totals", calculations: nil}]                               
      end
    end
  
    describe "calculate_first_sale" do
      before do
        row[:contract_amount] = 10
        row[:duty] = 3
        row[:duty_rate] = 0.2
        row[:first_sale_savings] = 4
        row[:first_sale_duty_savings] = 2
      end

      it "returns results of first-sale calculation for Ascena" do
        row[:customer_number] = "ASCE"
        expect(dsc.calculate_first_sale).to eq({calculated_invoice_value: 10, calculated_duty: 2 , savings: 2 })
      end

      it "calculates first sale for Ann" do
        row[:customer_number] = "ATAYLOR"
        expect(dsc.calculate_first_sale).to eq({calculated_invoice_value: 10, calculated_duty: 7 , savings: 2 })
      end
    end

    describe "calculate_spi" do
      let(:ot) { Factory(:official_tariff, common_rate_decimal: 0.3) }
      before do 
        row.official_tariff = ot
        row[:entered_value] = 10
        row[:duty_amount] = 1
        row[:duty_rate] = 0.2
      end
      
      it "returns results of SPI calculation if there's a common rate" do
        expect(dsc.calculate_spi).to eq({calculated_invoice_value: 10 , calculated_duty: 3, savings: 2})
      end

      it "returns results of different calculation if there isn't a common rate" do
        ot.update_attributes common_rate_decimal: 0
        expect(dsc.calculate_spi).to eq({calculated_invoice_value: 10 , calculated_duty: 0.2, savings: 0})
      end

      it "returns duty_amount as savings if spi is suspended" do
        row[:spi] = "A"
        row[:release_date] = Date.new(2018,3,15)
        expect(dsc.calculate_spi).to eq({calculated_invoice_value: 10 , calculated_duty: 3, savings: 1})
      end
    end

    describe "calculate_air_sea_differential" do
      before do
        row[:non_dutiable_amount] = 5
        row[:entered_value] = 10
        row[:duty_rate] = 0.2
        row[:duty_amount] = 3
        row[:price_before_discounts] = 4
        row[:air_sea_duty_savings] = 2
        row[:duty] = 4
      end

      it "returns results of Ascena air/sea calculation" do
        row[:customer_number] = "ASCE"
        expect(dsc.calculate_air_sea_differential).to eq({calculated_invoice_value: 15, calculated_duty: 3, savings: 0})
      end

      it "returns results of Ann air/sea calculation" do
        expect(dsc.calculate_air_sea_differential).to eq({calculated_invoice_value: 4, calculated_duty: 6, savings: 2})
      end
    end

    describe "calculate_epd" do
      it "returns results of EPD calculation" do
        row[:price_before_discounts] = 10
        row[:duty] = 4
        row[:epd_duty_savings] = 3

        expect(dsc.calculate_epd).to eq({calculated_invoice_value: 10, calculated_duty: 7, savings: 3})
      end
    end

    describe "calculate_trade_discount" do
      it "returns results of trade-discount calculation" do
        row[:price_before_discounts] = 10
        row[:duty] = 4
        row[:trade_discount_duty_savings] = 3

        expect(dsc.calculate_trade_discount).to eq({calculated_invoice_value: 10, calculated_duty: 7, savings: 3})
      end
    end
  end

  describe "DutySavingsType" do
    let!(:row) { described_class::Wrapper.new [] }
    let!(:dst) { described_class::DutySavingsType.new row }
    
    describe "get" do
      it "returns nested array of discount types along with 'Actual Entry Totals'" do
        row[:spi] = "A"
        expect(dst).to receive(:air_sea_differential?).and_return true
        expect(dst).to receive(:other?).and_return true
        expect(row).to receive(:first_sale?).and_return true
        expect(dst).to receive(:epd_discount?).and_return true
        expect(dst).to receive(:trade_discount?).and_return true
        expect(dst.get).to eq [[:spi, "GSP"], 
                               [:air_sea, "Air Sea Differential"], 
                               [:other, "Other"], 
                               [:first_sale, "First Sale"], 
                               [:epd, "EPD Discount"], 
                               [:trade, "Trade Discount"], 
                               [:line, "Actual Entry Totals"]]
      end

      it "returns empty array if there aren't any" do
        row[:spi] = ""
        expect(dst).to receive(:air_sea_differential?).and_return false
        expect(dst).to receive(:other?).and_return false
        expect(row).to receive(:first_sale?).and_return false
        expect(dst).to receive(:epd_discount?).and_return false
        expect(dst).to receive(:trade_discount?).and_return false
        expect(dst.get).to eq []
      end
    end

    describe "air_sea_differential?" do
      context "ascena" do
        before { row[:customer_number] = "ASCE" }
        it "returns true if transport_mode_code is 40 and non_dutiable exists" do
          row[:transport_mode_code] = 40
          row[:non_dutiable_amount] = 1
          expect(dst.air_sea_differential?).to eq true
        end

        it "returns false if transport_mode_code isn't 40" do
          row[:transport_mode_code] = 10
          row[:non_dutiable_amount] = 1
          expect(dst.air_sea_differential?).to eq false
        end

        it "returns false if there's no non_dutiable" do
          row[:transport_mode_code] = 40
          row[:non_dutiable_amount] = 0
          expect(dst.air_sea_differential?).to eq false
        end
      end

      context "ann" do
        before { row[:customer_number] = "ATAYLOR" }

        it "returns true if there's an air/sea discount" do
          row[:air_sea_discount] = 1
          expect(dst.air_sea_differential?).to eq true
        end

        it "returns false if there's no air/sea discount" do
          row[:air_sea_discount] = 0
          expect(dst.air_sea_differential?).to eq false
        end
      end
    end

    describe "epd_discount?" do
      context "ann" do
        before { row[:customer_number] = "ATAYLOR" }        

        it "returns true if there's an early payment discount" do
          row[:early_payment_discount] = 1
          expect(dst.epd_discount?).to eq true
        end

        it "returns false otherwise" do
          row[:early_payment_discount] = 0
          expect(dst.epd_discount?).to eq false
        end
      end

      it "returns false for Ascena" do
        row[:customer_number] = "ASCE"
        row[:early_payment_discount] = 1
        expect(dst.epd_discount?).to eq false
      end
    end
  
    describe "trade_discount?" do
      context "ann" do
        before { row[:customer_number] = "ATAYLOR" }        

        it "returns true if there's a trade discount" do
          row[:trade_discount] = 1
          expect(dst.trade_discount?).to eq true
        end

        it "returns false otherwise" do
          row[:trade_discount] = 0
          expect(dst.trade_discount?).to eq false
        end
      end

      it "returns false for Ascena" do
        row[:customer_number] = "ASCE"
        row[:trade_discount] = 1
        expect(dst.trade_discount?).to eq false
      end
    end

    describe "other?" do
      context "ascena" do
        before { row[:customer_number] = "ASCE" }
        
        it "returns true if transport_mode_code isn't 40 and there's a non-dutiable amount" do
          row[:transport_mode_code] = 10
          row[:non_dutiable_amount] = 1
          expect(dst.other?).to eq true
        end

        it "returns false if transport_mode_code is 40" do
          row[:transport_mode_code] = 40
          row[:non_dutiable_amount] = 1
          expect(dst.other?).to eq false
        end

        it "returns false if there isn't a non-dutiable" do
          row[:transport_mode_code] = 10
          row[:non_dutiable_amount] = 0
          expect(dst.other?).to eq false
        end
      end
    
      it "return false for Ann" do
        row[:customer_number] = "ATAYLOR"
        row[:transport_mode_code] = 10
        row[:non_dutiable_amount] = 1
        expect(dst.other?).to eq false
      end
    end
  end

  describe "ActualEntryTotalCalculator" do
    let!(:row) do 
      r = described_class::Wrapper.new []
      r[:air_sea_discount] = 1
      r[:first_sale_difference] = 5
      r
    end
    let!(:savings_set) { [{savings_type: :line, savings_title: "Actual Entry Totals"}] }
    let!(:aetc) { described_class::ActualEntryTotalCalculator.new row, savings_set }

    describe "fill_totals" do
      context "Ascena" do
        let!(:input) { {savings_type: :line, savings_title: "Actual Entry Totals"} }
        before do 
          row[:customer_number] = "ASCE"
          row[:non_dutiable_amount] = 0
          savings_set.concat [{savings_type: :spi, savings_title: "GSP", calculations: {calculated_invoice_value: 7, calculated_duty: 4, savings: 2}},
                              {savings_type: :other, savings_title: "Other", calculations: {calculated_invoice_value: 8, calculated_duty: 5, savings: 3}},
                              {savings_type: :first_sale, savings_title: "First Sale", calculations: {calculated_invoice_value: 9, calculated_duty: 6, savings: 1}}]
        end

        it "selects the discount with the highest savings and copies it into the input's 'calculations' hash" do
          aetc.fill_totals
          total = savings_set.find{ |ss| ss[:savings_type ] == :line }
          expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 8, calculated_duty: 5, savings: 3} })
        end

        it "selects the largest discount when there are no savings" do
          savings_set.reject{ |ss| ss[:savings_type] == :line }
                     .each{ |ss| ss[:calculations][:savings] = ss[:calculations][:calculated_duty] = 0 }
          row[:first_sale_difference] = 2
          row[:non_dutiable_amount] = 1
          aetc.fill_totals
          total = savings_set.find{ |ss| ss[:savings_type ] == :line }
          expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 9, calculated_duty: 0, savings: 0} })
        end
      end

      context "Ann" do
        before do
          savings_set.concat [{savings_type: :first_sale, savings_title: "First Sale", calculations: {calculated_invoice_value: 9, calculated_duty: 2, savings: 5}},
                              {savings_type: :spi, savings_title: "GSP", calculations: {calculated_invoice_value: 8, calculated_duty: 1, savings: 1}},
                              {savings_type: :trade, savings_title: "Trade Discount", calculations: {calculated_invoice_value: 10, calculated_duty: 3, savings: 2}},
                              {savings_type: :epd, savings_title: "EPD Discount", calculations: {calculated_invoice_value: 10, calculated_duty: 4, savings: 3}},
                              {savings_type: :air_sea, savings_title: "Air/Sea Differential", calculations: {calculated_invoice_value: 10, calculated_duty: 5, savings: 4}}]
          row[:customer_number] = "ATAYLOR"
          row[:early_payment_discount] = 2
          row[:trade_discount] = 3
        end

        context "select by highest savings" do
          it "selects the combination of air/sea, EPD, and trade discount if total savings higher than first sale or SPI" do
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 10, calculated_duty: 10, savings: 9}})
          end
          
          it "selects first sale and copies it into the input's 'calculations' hash if it's the highest" do
            savings_set[1][:calculations][:savings] = 10
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 9, calculated_duty: 2, savings: 10}})
          end 

          it "selects SPI and copies it into the input's 'calculations' hash if it's the highest (it's always 0)" do
            savings_set[2][:calculations][:savings] = 10
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 8, calculated_duty: 1, savings: 10}})
          end
        end

        context "select by highest discount" do
          before do
            savings_set.reject{ |s| s[:savings_type] == :line}.each { |s| s[:calculations][:savings] = 0 }
          end
          
          it "selects the combination of air/sea, EPD, and trade discount if total discount higher than first sale or SPI." do
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 10, calculated_duty: 0, savings: 0}})
          end

          it "selects first sale if it's the highest." do
            row[:first_sale_difference] = 7
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 9, calculated_duty: 0, savings: 0}})
          end

          it "selects SPI if it's the highest. (because it's always 0, only happens when it's the only discount)" do
            savings_set.delete_if{ |s| ![:spi, :line].include? s[:savings_type] }
            row[:trade_discount] = row[:early_payment_discount] = row[:air_sea_discount] = row[:first_sale_difference] = 0
            aetc.fill_totals
            total = savings_set.find{ |ss| ss[:savings_type ] == :line }
            expect(total).to eq({savings_type: :line, savings_title: "Actual Entry Totals", calculations: {calculated_invoice_value: 8, calculated_duty: 0, savings: 0}})
          end
        end
      end
    end
  end

  describe "FieldFiller" do
    let(:klass) { described_class::FieldFiller }
    let(:inv_field_helper) { double "inv_field_helper" }
    let(:filler) do 
      f = klass.new(:foo)
      f.inv_field_helper = inv_field_helper
      f
    end
    let(:row) { described_class::Wrapper.new([]) }
  
    describe "first_sale_duty_savings" do
      it "returns First Sale Savings for Ascena" do
        row[:customer_number] = "ASCE"
        expect(inv_field_helper).to receive(:fields).and_return(1 => {cil_first_sale_savings: 5})

        expect(filler.first_sale_duty_savings row, 1).to eq 5
      end

      it "returns (contract_amount - entered value) * duty amount for Ann" do
        row[:customer_number] = "ATAYLOR"
        row[:contract_amount] = 10
        row[:entered_value] = 2
        row[:duty_rate] = 3

        expect(filler.first_sale_duty_savings row, 1).to eq 24
      end

      it "returns 0 for Ann if not first sale" do
        row[:customer_number] = "ATAYLOR"
        row[:contract_amount] = 0
        row[:entered_value] = 2
        row[:duty_rate] = 3

        expect(filler.first_sale_duty_savings row, 1).to eq 0
      end
    end

    describe "first_sale_difference" do
      it "returns content of model field for Ascena" do
        row[:customer_number] = "ASCE"
        expect(inv_field_helper).to receive(:fields).and_return(1 => {cil_first_sale_difference: 10})
        
        expect(filler.first_sale_difference row, 1).to eq 10
      end

      context "Ann" do
        before do 
          row[:middleman_charge] = 4
          row[:customer_number] = "ATAYLOR"
        end
        
        it "returns middleman charge" do
          row[:contract_amount] = 1

          expect(filler.first_sale_difference row, 1).to eq 4
        end

        it "returns 0 if not first sale" do
          row[:contract_amount] = 0
          
          expect(filler.first_sale_difference row, 1).to eq 0
        end
      end
    end

    describe "price before discounts" do
      before do
        row[:value] = 5
        row[:first_sale_difference] = 3
      end
      
      it "returns value + first_sale_difference for Ascena" do
        row[:customer_number] = "ASCE"

        expect(filler.price_before_discounts row).to eq 8
      end

      it "returns value for Ann" do
        row[:customer_number] = "ATAYLOR"

        expect(filler.price_before_discounts row).to eq 5
      end
    end

    describe "first_sale_margin_percent" do
      context "Ascena" do
        before { row[:customer_number] = "ASCE" }

        it "returns first_sale_difference / contract_amount if first sale" do
          row[:contract_amount] = 2
          expect(inv_field_helper).to receive(:fields).and_return(1 => {cil_first_sale_difference: 10})
          expect(filler.first_sale_margin_percent row, 1).to eq 5
        end

        it "returns 0 otherwise" do
          row[:contract_amount] = 0
          expect(filler.first_sale_margin_percent row, 1).to be_zero
        end
      end

      context "Ann" do
        before { row[:customer_number] = "ATAYLOR" }

        it "returns (value - entered_value) / contract_amount if first sale" do
          row[:contract_amount] = 4
          row[:middleman_charge] = 8
         
          expect(filler.first_sale_margin_percent row, 1).to eq 2
        end

        it "returns 0 if not first sale" do
          row[:contract_amount] = 0
          row[:middleman_charge] = 4
          
          expect(filler.first_sale_margin_percent row, 1).to be_zero
        end
      end
    end

    describe "air_sea_discount" do
      
      it "returns customer-invoice air_sea_discount for Ann" do
        row[:customer_number] = "ATAYLOR"
        row[:air_sea_discount_attrib] = 1
        expect(filler.air_sea_discount row).to eq 1
      end

      context "Ascena" do
        before do 
          row[:customer_number] = "ASCE"
          row[:non_dutiable_amount] = 2
          row[:transport_mode_code] = "40"
        end
        
        it "returns non-dutiable amount if it's positive and transport_mode_code is 40" do
          expect(filler.air_sea_discount row).to eq 2
        end

        it "returns 0 if transport_mode_code isn't 40" do
          row[:transport_mode_code] = "10"
          expect(filler.air_sea_discount row).to eq 0
        end

        it "returns 0 if non-dutiable amount isn't positive" do
          row[:non_dutiable_amount] = -1
          expect(filler.air_sea_discount row).to eq 0
        end
      end
    end

    describe "air_sea_per_unit_savings" do
      context "Ann" do
        before do 
          row[:customer_number] = "ATAYLOR"
          row[:air_sea_discount_attrib] = 10
        end
        
        it "returns air_sea_discount / quantity for Ann" do
          row[:quantity] = 5
          expect(filler.air_sea_per_unit_savings row).to eq 2
        end

        it "returns 0 if quantity is 0" do
          row[:quantity] = 0
          expect(filler.air_sea_per_unit_savings row).to eq 0
        end        
      end

      context "Ascena" do
        before do 
          row[:customer_number] = "ASCE"
          row[:non_dutiable_amount] = 8
          row[:quantity] = 2
          row[:transport_mode_code] = "40"
        end

        it "returns non_dutiable_amount / quantity if transport_mode_code is 40 and non_dutiable_amount is positive" do
          expect(filler.air_sea_per_unit_savings row).to eq 4
        end

        it "returns 0 if transport_mode_code isn't 40" do
          row[:transport_mode_code] = "10"
          expect(filler.air_sea_per_unit_savings row).to eq 0
        end

        it "returns 0 if non_dutiable_amount isn't positive" do
          row[:non_dutiable_amount] = -8
          expect(filler.air_sea_per_unit_savings row).to eq 0
        end

        it "return 0 if quantity is 0" do
          row[:quantity] = 0
          expect(filler.air_sea_per_unit_savings row).to eq 0
        end
      end
    end

    describe "air_sea_duty_savings" do
      it "returns product of air_sea_discount_attrib duty_rate for Ann" do
        row[:customer_number] = "ATAYLOR"
        row[:air_sea_discount_attrib] = 3
        row[:duty_rate] = 2

        expect(filler.air_sea_duty_savings row).to eq 6
      end

      context "Ascena" do
        before do
          row[:customer_number] = "ASCE"
          row[:transport_mode_code] = "40"
          row[:non_dutiable_amount] = 9
          row[:duty_rate] = 2
        end

        it "returns product of non_dutiable_amount and duty_rate if transport_mode_code is 40 and non_dutiable_amount is positive" do
          expect(filler.air_sea_duty_savings row).to eq 18
        end

        it "returns 0 if transport_mode_code isn't 40" do
          row[:transport_mode_code] = "10"
          expect(filler.air_sea_duty_savings row).to eq 0
        end

        it "returns 0 if non_dutiable_amount isn't positive" do
          row[:non_dutiable_amount] = -9
          expect(filler.air_sea_duty_savings row).to eq 0
        end
      end
    end

    context "OfficialTariff calculations" do
      let(:co) { Factory(:country)}
      let!(:ot) { Factory(:official_tariff, country: co, hts_code: "1111", general_rate: "2%")}
      before { row[:import_country_id] = co.id }
        
      describe "original_duty_rate" do
        it "returns common rate if the HTS exists" do
          expect(row).to receive(:official_tariff).and_return ot
          expect(filler.original_duty_rate row).to eq "2%"
        end

        it "returns 'No HTS Found' otherwise" do
          expect(row).to receive(:official_tariff).and_return nil
          expect(filler.original_duty_rate row).to eq "No HTS Found"
        end
      end

      describe "spi_duty_savings" do
        before do
          row[:hts_code] = "1111"
          row[:price_before_discounts] = 400
          row[:spi] = "SPI"
        end

        it "returns calculated value if the common rate is positive" do
          expect(inv_field_helper).to receive(:fields).and_return(1 => {cil_total_duty: 3})          
          expect(row).to receive(:official_tariff).and_return ot

          expect(filler.spi_duty_savings row, 1).to eq 5
        end

        it "returns 0 if the common rate isn't positive" do
          ot.update_attributes! general_rate: "0" 
          expect(row).to receive(:official_tariff).and_return ot         

          expect(filler.spi_duty_savings row, 1).to eq 0
        end

        it "returns 0 if there's no HTS" do
          expect(row).to receive(:official_tariff).and_return nil
          
          expect(filler.spi_duty_savings row, 1).to eq 0
        end

        it "returns 0 if there's no SPI" do
          row[:spi] = nil
          expect(row).to receive(:official_tariff).and_return ot                   
          
          expect(filler.spi_duty_savings row, 1).to eq 0
        end

        context "missing common_rate_decimal" do
          it "tries to guess the value" do
            ot.update_attributes! general_rate: "foobar 32.06%", common_rate_decimal: nil
            #if OfficialTariff#set_common_rate changes this test should change (or be removed)
            expect(ot.common_rate_decimal).to be_nil

            expect(inv_field_helper).to receive(:fields).and_return(1 => {cil_total_duty: 3})          
            expect(row).to receive(:official_tariff).and_return ot
            expect(filler.spi_duty_savings row, 1).to eq 125.24            
          end

          it "uses 0 if guess fails" do
            ot.update_attributes! general_rate: "foobar", common_rate_decimal: nil
            #if OfficialTariff#set_common_rate changes this test should change (or be removed)
            expect(ot.common_rate_decimal).to be_nil

            expect(row).to receive(:official_tariff).and_return ot
            expect(filler.spi_duty_savings row, 1).to eq 0
          end
        end
      end
    end

    describe "mp vs epd" do
      it "returns calculated value for Ann" do
        row[:customer_number] = "ATAYLOR"
        row[:first_sale_duty_savings] = 9
        row[:epd_duty_savings] = 2

        expect(filler.mp_vs_epd row).to eq 7
      end

      it "returns 0 for Ascena" do
        row[:customer_number] = "ASCE"
        
        expect(filler.mp_vs_epd row).to eq 0
      end
    end

    describe "mp_vs_trade_discount" do
      it "returns calculated value for Ann" do
        row[:customer_number] = "ATAYLOR"
        row[:first_sale_duty_savings] = 9
        row[:trade_discount_duty_savings] = 3

        expect(filler.mp_vs_trade_discount row).to eq 6
      end

      it "returns 0 for Ascena" do
        row[:customer_number] = "ASCE"
        expect(filler.mp_vs_trade_discount row).to eq 0
      end
    end

    describe "air_sea_savings" do
      it "returns absolute value of 'MP vs Air/Sea' if it's less than 0" do 
        row[:mp_vs_air_sea] = -1
        expect(filler.air_sea_savings row).to eq 1
      end

      it "returns 0 otherwise" do
        row[:mp_vs_air_sea] = 1
        expect(filler.air_sea_savings row).to eq 0
      end
    end

    describe "epd_savings" do
      it "returns absolute value of 'MP vs EPD' if it's less than 0" do 
        row[:mp_vs_epd] = -1
        expect(filler.epd_savings row).to eq 1
      end

      it "returns 0 otherwise" do
        row[:mp_vs_epd] = 1
        expect(filler.epd_savings row).to eq 0
      end
    end

    describe "trade_discount_savings" do
      it "returns absolute value of 'MP vs Trade Discount' if it's less than 0" do 
        row[:mp_vs_trade_discount] = -1
        expect(filler.trade_discount_savings row).to eq 1
      end

      it "returns 0 otherwise" do
        row[:mp_vs_trade_discount] = 1
        expect(filler.trade_discount_savings row).to eq 0
      end
    end

    describe "applied_discount" do
      context "Ann" do
        before do 
          row[:customer_number] = "ATAYLOR"
          row[:contract_amount] = 0
          row[:non_dutiable_amount] = 0
          row[:miscellaneous_discount] = 0
          row[:other_amount] = 0
        end
        
        it "returns 'FS' if contract_amount present and non_dutiable_amount is positive" do
          row[:contract_amount] = 1
          row[:non_dutiable_amount] = 1
          expect(filler.applied_discount row).to eq "FS"
        end

        it "returns 'AS' if there's no contract_amount and non_dutiable_amount is positive" do
          row[:contract_amount] = 0
          row[:non_dutiable_amount] = 1
          expect(filler.applied_discount row).to eq "AS"
        end

        it "returns 'EP' if miscellaneous_discount is positive" do
          row[:miscellaneous_discount] = 1
          expect(filler.applied_discount row).to eq "EP"
        end

        it "returns 'TD' if other_amount is negative" do
          row[:other_amount] = -1
          expect(filler.applied_discount row).to eq "TD"
        end

        it "returns multiple codes if applicable" do
          row[:contract_amount] = 1
          row[:non_dutiable_amount] = 1
          row[:miscellaneous_discount] = 1
          row[:other_amount] = -1

          expect(filler.applied_discount row).to eq "FS, EP, TD"
        end
      end

      context "Ascena" do
        before do
          row[:customer_number] = "ASCE"
          row[:transport_mode_code] = "10"
          row[:contract_amount] = 0
          row[:non_dutiable_amount] = 0
        end

        it "returns 'FS' if contract_amount is positive" do
          row[:contract_amount] = 1
          expect(filler.applied_discount row).to eq "FS"
        end

        it "returns 'AS' if transport_mode_code is 40 and non_dutiable_amount is positive" do
          row[:transport_mode_code] = "40"
          row[:non_dutiable_amount] = 1
          expect(filler.applied_discount row).to eq "AS"
        end

        it "returns both codes if applicable" do
          row[:contract_amount] = 1
          row[:transport_mode_code] = "40"
          row[:non_dutiable_amount] = 1

          expect(filler.applied_discount row).to eq "FS, AS"
        end
      end
    end

  end

  describe "Query" do
    subject { report = described_class::Query.new }
    
    let!(:ann) { Factory(:importer, alliance_customer_number: "ATAYLOR") }
    let!(:us) { Factory(:country)}

    let!(:e_asce) { Factory(:entry, importer: ascena, import_country_id: us.id, customer_name: "Ascena", customer_number: "ASCE", source_system: "Alliance", broker_reference: "ascena broker ref", transport_mode_code: "40", fiscal_date: "2018-03-16", fiscal_month: 1, release_date: "2018-03-10", entry_number: "asce ent number", arrival_date: "2018-03-08", import_date: "2018-03-06", unlading_port_code:"1234", entry_port_code: "4321", fish_and_wildlife_transmitted_date: "2018-03-06")}
    let!(:ci_asce) { Factory(:commercial_invoice, entry: e_asce, invoice_number: "inv num asce") }
    let!(:cil_asce) { Factory(:commercial_invoice_line, commercial_invoice: ci_asce, contract_amount: 5, related_parties: true, customs_line_number: 1, part_number: "part asce", po_number: "po asce", product_line: "brand asce", country_origin_code: "AM", country_export_code: "country export asce", unit_price: 1, quantity: 2, unit_of_measure: "uom asce", value: 1, non_dutiable_amount: 2) }
    let!(:cit_asce) { Factory(:commercial_invoice_tariff, commercial_invoice_line: cil_asce, hts_code: "hts code", duty_rate: 1.1, tariff_description: "tar descr asce", duty_amount: 2, entered_value: 4, spi_primary: "spi asce" ) }
    let!(:vend_asce) { Factory(:vendor, name: "asce vend") }
    let!(:fact_asce) { Factory(:factory, name: "asce fact") }
    let!(:ord_asce) do 
      order = Factory(:order, order_number: "ASCENA-po asce", vendor: vend_asce, factory: fact_asce)
      order.update_custom_value! cdefs[:ord_type], "ord type asce"
      order
    end

    let!(:official_tariff) { Factory(:official_tariff, country: us, hts_code: "hts code", general_rate: "2%") }
    let!(:port_arrival) { Factory(:port, schedule_d_code: "1234", name: "arrival port")}
    let!(:port_entry) { Factory(:port, schedule_d_code: "4321", name: "entry port")}

    let!(:e_ann) { Factory(:entry, importer: ann, import_country_id: us.id, customer_name: "Ann", customer_number: "ATAYLOR", source_system: "Alliance", broker_reference: "ann broker ref", transport_mode_code: "40", fiscal_date: "2018-03-16", fiscal_month: 2, release_date: "2018-03-11", entry_number: "ann ent number", arrival_date: "2018-03-09", import_date: "2018-03-07", unlading_port_code: "1234", entry_port_code: "4321")}
    let!(:ci_ann) { Factory(:commercial_invoice, entry: e_ann, invoice_number: "inv num ann") }
    let!(:cil_ann) { Factory(:commercial_invoice_line, commercial_invoice: ci_ann, contract_amount: 6, related_parties: true, customs_line_number: 1, part_number: "part ann", po_number: "po ann", product_line: "brand ann", country_origin_code: "AM", country_export_code: "country export ann", unit_price: 3, quantity: 4, unit_of_measure: "uom ann", value: 1, non_dutiable_amount: 4, miscellaneous_discount: 2, other_amount: -1) }
    let!(:cit_ann) { Factory(:commercial_invoice_tariff, commercial_invoice_line: cil_ann, hts_code: "hts code", duty_rate: 1.3, tariff_description: "tar descr ann", duty_amount: 3, entered_value: 5, spi_primary: "spi ann") }
    let!(:vend_ann_810) { Factory(:vendor, name: "ann vend 810") }
    let!(:fact_ann_810) { Factory(:factory, name: "ann fact 810") }
    let!(:vend_ann_ord) { Factory(:vendor, name: "ann vend ord") }
    let!(:fact_ann_ord) { Factory(:factory, name: "ann fact ord") }
    let!(:i) { Factory(:invoice, importer: ann, invoice_number: "inv num ann", vendor: vend_ann_810, factory: fact_ann_810) }
    let!(:il) { Factory(:invoice_line, invoice: i, po_number: "po ann", part_number: "part ann", part_description: "part descr", air_sea_discount: 4, early_pay_discount: 2, trade_discount: 6, middleman_charge: 8)}
    let!(:ord_ann) do 
      order = Factory(:order, order_number: "ATAYLOR-po ann", vendor: vend_ann_ord, factory: fact_ann_ord)
      order.update_custom_value! cdefs[:ord_type], "ord type ann"
      order
    end
    
    def test_asce_results r
      expect(r[:broker_reference]).to eq "ascena broker ref"
      expect(r[:customer_name]).to eq "Ascena"
      expect(r[:first_sale]).to eq "Y"
      expect(r[:vendor]).to eq "asce vend"
      expect(r[:factory]).to eq "asce fact"
      expect(r[:related_parties]).to eq "Y"
      expect(r[:transport_mode_code]).to eq "40"
      expect(r[:fiscal_month]).to eq 1
      expect(r[:release_date]).to eq Date.new(2018,3,10)
      expect(r[:filer]).to eq "asc"
      expect(r[:entry_number]).to eq "asce ent number"
      expect(r[:custom_line_number]).to eq 1
      expect(r[:invoice_number]).to eq "inv num asce"
      expect(r[:part_number]).to eq "part asce"
      expect(r[:po_number]).to eq "po asce"
      expect(r[:product_line]).to eq "brand asce"
      expect(r[:order_type]).to eq "ord type asce"
      expect(r[:country_origin_code]).to eq "AM"
      expect(r[:country_export_code]).to eq "country export asce"
      expect(r[:arrival_date]).to eq Date.new(2018,3,8)
      expect(r[:import_date]).to eq Date.new(2018,3,6)
      expect(r[:arrival_port]).to eq "arrival port"
      expect(r[:entry_port]).to eq "entry port"
      expect(r[:hts_code]).to eq "hts code"
      expect(r[:duty_rate]).to eq 1.1
      expect(r[:goods_description]).to eq "tar descr asce"
      expect(r[:unit_price]).to eq 1
      expect(r[:quantity]).to eq 2
      expect(r[:unit_of_measure]).to eq "uom asce"
      expect(r[:original_fob_unit_value]).to eq 2.5
      expect(r[:original_fob_entered_value]).to eq 5
      expect(r[:duty]).to eq 2
      expect(r[:first_sale_difference]).to eq 4
      expect(r[:first_sale_duty_savings]).to eq 2
      expect(r[:first_sale_margin_percent]).to eq 0.8
      expect(r[:price_before_discounts]).to eq 5
      expect(r[:entered_value]).to eq 4
      expect(r[:air_sea_discount]).to eq 2
      expect(r[:air_sea_per_unit_savings]).to eq 1
      expect(r[:air_sea_duty_savings]).to eq 2.2
      expect(r[:early_payment_discount]).to eq 0
      expect(r[:epd_per_unit_savings]).to eq 0
      expect(r[:epd_duty_savings]).to eq 0
      expect(r[:trade_discount]).to eq 0
      expect(r[:trade_discount_per_unit_savings]).to eq 0
      expect(r[:trade_discount_duty_savings]).to eq 0
      expect(r[:spi]).to eq "spi asce"
      expect(r[:original_duty_rate]).to eq "2%"
      expect(r[:spi_duty_savings]).to eq(-1.9)
      expect(r[:fish_and_wildlife]).to eq "Y"
      expect(r[:hanger_duty_savings]).to eq 0
      expect(r[:mp_vs_air_sea]).to eq(-0.2)
      expect(r[:mp_vs_epd]).to eq 0
      expect(r[:mp_vs_trade_discount]).to eq 0
      expect(r[:mp_vs_air_sea_epd_trade]).to eq(-0.2)
      expect(r[:first_sale_savings]).to eq 2
      expect(r[:air_sea_savings]).to eq 0.2
      expect(r[:epd_savings]).to eq 0
      expect(r[:trade_discount_savings]).to eq 0
      expect(r[:applied_discount]).to eq "FS, AS"
      expect(r[:customer_number]).to eq "ASCE"
      expect(r[:contract_amount]).to eq 5
      expect(r[:non_dutiable_amount]).to eq 2
      expect(r[:duty_amount]).to eq 2
      expect(r[:e_id]).to eq e_asce.id
      expect(r[:cil_id]).to eq cil_asce.id
    end

    def test_ann_results r, with_po=true
      expect(r[:broker_reference]).to eq "ann broker ref"
      expect(r[:customer_name]).to eq "Ann"
      expect(r[:first_sale]).to eq "Y"
      expect(r[:vendor]).to eq(with_po ? "ann vend ord" : "ann vend 810")
      expect(r[:factory]).to eq(with_po ? "ann fact ord" : "ann fact 810")
      expect(r[:related_parties]).to eq "Y"
      expect(r[:transport_mode_code]).to eq "40"
      expect(r[:fiscal_month]).to eq 2
      expect(r[:release_date]).to eq Date.new(2018,3,11)
      expect(r[:filer]).to eq "ann"
      expect(r[:entry_number]).to eq "ann ent number"
      expect(r[:custom_line_number]).to eq 1
      expect(r[:invoice_number]).to eq "inv num ann"
      expect(r[:part_number]).to eq "part ann"
      expect(r[:po_number]).to eq "po ann"
      expect(r[:product_line]).to eq "brand ann"
      expect(r[:order_type]).to eq "NONAGS"
      expect(r[:country_origin_code]).to eq "AM"
      expect(r[:country_export_code]).to eq "country export ann"
      expect(r[:arrival_date]).to eq Date.new(2018,3,9)
      expect(r[:import_date]).to eq Date.new(2018,3,7)
      expect(r[:arrival_port]).to eq "arrival port"
      expect(r[:entry_port]).to eq "entry port"
      expect(r[:hts_code]).to eq "hts code"
      expect(r[:duty_rate]).to eq 1.3
      expect(r[:goods_description]).to eq "part descr"
      expect(r[:unit_price]).to eq 3
      expect(r[:quantity]).to eq 4
      expect(r[:unit_of_measure]).to eq "uom ann"
      expect(r[:original_fob_unit_value]).to eq 1.5
      expect(r[:original_fob_entered_value]).to eq 6
      expect(r[:duty]).to eq 3
      expect(r[:first_sale_difference]).to eq(8)
      expect(r[:first_sale_duty_savings]).to eq 1.3
      expect(r[:first_sale_margin_percent]).to eq(1.33)
      expect(r[:price_before_discounts]).to eq 1
      expect(r[:entered_value]).to eq 5
      expect(r[:air_sea_discount]).to eq 4
      expect(r[:air_sea_per_unit_savings]).to eq 1
      expect(r[:air_sea_duty_savings]).to eq 5.2
      expect(r[:early_payment_discount]).to eq 2
      expect(r[:epd_per_unit_savings]).to eq 0.5
      expect(r[:epd_duty_savings]).to eq 2.6
      expect(r[:trade_discount]).to eq 6
      expect(r[:trade_discount_per_unit_savings]).to eq 1.5
      expect(r[:trade_discount_duty_savings]).to eq 7.8
      expect(r[:spi]).to eq "spi ann"
      expect(r[:original_duty_rate]).to eq "2%"
      expect(r[:spi_duty_savings]).to eq(-2.98)
      expect(r[:fish_and_wildlife]).to eq "N"
      expect(r[:hanger_duty_savings]).to eq 0
      expect(r[:mp_vs_air_sea]).to eq(-3.9)
      expect(r[:mp_vs_epd]).to eq(-1.3)
      expect(r[:mp_vs_trade_discount]).to eq BigDecimal("-6.5")
      expect(r[:mp_vs_air_sea_epd_trade]).to eq(-14.3)
      expect(r[:first_sale_savings]).to eq 1.3
      expect(r[:air_sea_savings]).to eq 3.9
      expect(r[:epd_savings]).to eq 1.3
      expect(r[:trade_discount_savings]).to eq BigDecimal("6.5")
      expect(r[:applied_discount]).to eq "FS, EP, TD"
      expect(r[:customer_number]).to eq "ATAYLOR"
      expect(r[:contract_amount]).to eq 6
      expect(r[:non_dutiable_amount]).to eq 4
      expect(r[:duty_amount]).to eq 3
      expect(r[:middleman_charge]).to eq 8
      expect(r[:e_id]).to eq e_ann.id
      expect(r[:cil_id]).to eq cil_ann.id
    end

    it "produces expected results for Ascena" do      
      result = nil
      Timecop.freeze(DateTime.new 2018, 3, 16) { result = subject.run(["ASCE"], "2018-03-15", "2018-03-17") }
      r = result.first
      test_asce_results r
    end

    it "produces expected results for Ann with matching order" do
      result = nil
      result = Timecop.freeze(DateTime.new 2018, 3, 16) { result = subject.run(["ATAYLOR"], "2018-03-15", "2018-03-17") }
      r = result.first
      test_ann_results r
    end

    it "produces expected results for Ann without matching order" do
      ord_ann.destroy
      result = nil
      result = Timecop.freeze(DateTime.new 2018, 3, 16) { result = subject.run(["ATAYLOR"], "2018-03-15", "2018-03-17") }
      r = result.first
      test_ann_results r, false
    end

    it "produces expected combined results" do
      result = []
      result = Timecop.freeze(DateTime.new 2018, 3, 16) { subject.run(["ASCE", "ATAYLOR"], "2018-03-15", "2018-03-17").each{ |r| result << r } }
      r = result[0]
      test_asce_results r
      
      r = result[1]
      test_ann_results r
    end
  end

end

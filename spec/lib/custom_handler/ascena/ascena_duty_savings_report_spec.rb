describe OpenChain::CustomHandler::Ascena::AscenaDutySavingsReport do

  subject { described_class }
  let (:ascena) { Factory(:importer, alliance_customer_number: "ASCE") }

  describe "permission?" do
  
    before(:each) do
      ascena
      ms = stub_master_setup
      allow(ms).to receive(:system_code).and_return "www-vfitrack-net"
    end

    it "allows access for master users who can view entries" do
      u = Factory(:master_user)
      expect(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for Ascena users who can view entries" do
      u = Factory(:user, company: ascena)
      expect(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "allows access for users of Ascena's parent companies" do
      parent = Factory(:company, linked_companies: [ascena])
      u = Factory(:user, company: parent)
      expect(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq true
    end

    it "prevents access by other companies" do
      u = Factory(:user)
      expect(u).to receive(:view_entries?).and_return true
      expect(subject.permission? u).to eq false
    end

    it "prevents access by users who can't view entries" do
      u = Factory(:master_user)
      expect(u).to receive(:view_entries?).and_return false
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

  describe "run_report" do

    let! (:entry) {
      e = Factory(:entry, importer: ascena, customer_number: "ASCE", source_system: "Alliance", fiscal_date: Date.new(2017, 3, 1), broker_reference: "REF", transport_mode_code: "10", fiscal_year: 2017, fiscal_month: 3, release_date: DateTime.new(2017, 3, 1, 5, 0))
      inv = e.commercial_invoices.create! invoice_number: "INV"
      line = inv.commercial_invoice_lines.create! po_number: "PO", part_number: "PART", product_line: "JST", non_dutiable_amount: 0, contract_amount: 0
      tariff = line.commercial_invoice_tariffs.create! hts_code: "1234567890", tariff_description: "DESC", entered_value: BigDecimal("10"), spi_primary: "", duty_rate: BigDecimal("0.1"), duty_amount: BigDecimal("1")

      line = inv.commercial_invoice_lines.create! po_number: "PO", part_number: "PART2", product_line: "JST", non_dutiable_amount: 0, contract_amount: 0
      tariff = line.commercial_invoice_tariffs.create! hts_code: "1234567890", tariff_description: "DESC", entered_value: BigDecimal("10"), spi_primary: "", duty_rate: BigDecimal("0.1"), duty_amount: BigDecimal("1")

      e
    }

    let! (:fiscal_month) { Factory(:fiscal_month, company: ascena, year: 2017, month_number: 3, start_date: Date.new(2017, 3, 1), end_date: Date.new(2017, 4, 1)) }

    it "skips anything that does not have duty savings" do
      tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
      expect(tf).not_to be_nil

      wb = XlsMaker.open_workbook(tf)
      expect(sheet = wb.worksheet("Summary")).not_to be_nil
      expect(sheet.row(0)).to eq ["Program Name", "Entry Count", "Total Entered Value", "Total Duty Paid", "Total Calculated Entered Value", "Total Calculated Duty", "Duty Savings", "Duty Savings Percentage"]
      # Since there was no savings, only the header row is present
      expect(sheet.rows.count).to eq 1

      expect(sheet = wb.worksheet("First Sale")).not_to be_nil
      expect(sheet.rows.count).to eq 5
      expect(sheet.row(0)).to eq [nil, "Tweenbrands", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn"]
      expect(sheet.row(1)).to eq ["Vendor Invoice", 0, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(2)).to eq ["Entered Value", 0, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(3)).to eq ["Duty Savings", 0, nil, nil, nil, nil, nil, nil, nil, nil]
      expect(sheet.row(4)).to eq ["Total Brand FOB Receipts", 20, nil, nil, nil, nil, nil, nil, nil, nil]

      expect(sheet = (wb.worksheet "Data")).not_to be_nil
      expect(sheet.rows.count).to eq 3
      expect(sheet.row(0)).to eq ["Broker Reference", "Transport Mode Code", "Fiscal Month", "Release Date", "Invoice Number", "PO Number", "Part Number", "Brand", "Non-Dutiable Amount", "First Sale Cost", "HTS Code", "Tariff Description", "Entered Value", "SPI", "Duty Rate", "Duty Amount", "Calculated Entered Value", "Calculated Duty", "Duty Savings"]
      expect(sheet.row(1)).to eq ["REF", "10", "2017-03", excel_date(Date.new(2017, 3, 1)), "INV", "PO", "PART", "JST", 0, 0, "1234567890", "DESC", 10, nil, 0.1, 1, 10, 1, 0]
      expect(sheet.row(2)).to eq ["REF", "10", "2017-03", excel_date(Date.new(2017, 3, 1)), "INV", "PO", "PART2", "JST", 0, 0, "1234567890", "DESC", 10, nil, 0.1, 1, 10, 1, 0]
    end

    it "records air/sea differential amounts" do
      entry.update_attributes! transport_mode_code: "40"
      entry.commercial_invoice_lines.each {|line| line.update_attributes! non_dutiable_amount: 20 }

      tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("Summary")
      expect(sheet.rows.count).to eq 2
      expect(sheet.row(1)).to eq ["Air Sea Differential", 1, 20, 2, 60, 6, 4, 66.67]
    end

    it "records first sale amounts" do
      entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20 }
      tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("Summary")
      expect(sheet.rows.count).to eq 2
      expect(sheet.row(1)).to eq ["First Sale", 1, 20, 2, 40, 4, 2, 50]
    end

    it "records 'Other' duty savings" do
      # This is anything with a non-dutiable amount that is NOT an Air entry
      entry.commercial_invoice_lines.each {|line| line.update_attributes! non_dutiable_amount: 20 }

      tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
      wb = XlsMaker.open_workbook(tf)

      sheet = wb.worksheet("Summary")
      expect(sheet.rows.count).to eq 2
      expect(sheet.row(1)).to eq ["Other", 1, 20, 2, 60, 6, 4, 66.67]
    end

    context "with SPI" do
      let! (:us) { Factory(:country, iso_code: "US") }
      let! (:offical_tariff) { OfficialTariff.create! country_id: us.id, hts_code: "1234567890", common_rate: "20%", common_rate_decimal: 0.2}

      it "records Jordan FTA duty savings" do
        entry.commercial_invoice_lines.each do |line| 
          line.commercial_invoice_tariffs.each do |t|
            t.update_attributes! spi_primary: "JO" 
          end
        end

        tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("Summary")
        expect(sheet.rows.count).to eq 2
        expect(sheet.row(1)).to eq ["Jordan FTA", 1, 20, 2, 20, 4, 2, 50]
      end

      it "records CAFTA FTA duty savings" do
        entry.commercial_invoice_lines.each do |line| 
          line.commercial_invoice_tariffs.each do |t|
            t.update_attributes! spi_primary: "P" 
          end
        end

        tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("Summary")
        expect(sheet.rows.count).to eq 2
        expect(sheet.row(1)).to eq ["CAFTA", 1, 20, 2, 20, 4, 2, 50]
      end
    end

    context "first sale tab" do
      it "records tween brands first sale data" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "JST" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.rows.count).to eq 5
        expect(sheet.row(0)).to eq [nil, "Tweenbrands", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn"]
        expect(sheet.row(1)).to eq ["Vendor Invoice", 40, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(2)).to eq ["Entered Value", 20, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(3)).to eq ["Duty Savings", 2, nil, nil, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(4)).to eq ["Total Brand FOB Receipts", 40, nil, nil, nil, nil, nil, nil, nil, nil]
      end

      it "records Lane Bryant first sale data" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "LB" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.rows.count).to eq 5
        expect(sheet.row(0)).to eq [nil, "Tweenbrands", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn"]
        expect(sheet.row(1)).to eq ["Vendor Invoice", nil, nil, 40, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(2)).to eq ["Entered Value", nil, nil, 20, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(3)).to eq ["Duty Savings", nil, nil, 2, nil, nil, nil, nil, nil, nil]
        expect(sheet.row(4)).to eq ["Total Brand FOB Receipts", nil, nil, 40, nil, nil, nil, nil, nil, nil]
      end

      it "records Catherines first sale data" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "CA" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.rows.count).to eq 5
        expect(sheet.row(0)).to eq [nil, "Tweenbrands", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn"]
        expect(sheet.row(1)).to eq ["Vendor Invoice", nil, nil, nil, nil, 40, nil, nil, nil, nil]
        expect(sheet.row(2)).to eq ["Entered Value", nil, nil, nil, nil, 20, nil, nil, nil, nil]
        expect(sheet.row(3)).to eq ["Duty Savings", nil, nil, nil, nil, 2, nil, nil, nil, nil]
        expect(sheet.row(4)).to eq ["Total Brand FOB Receipts", nil, nil, nil, nil, 40, nil, nil, nil, nil]
      end

      it "records Maurices first sale data" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "MAU" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.rows.count).to eq 5
        expect(sheet.row(0)).to eq [nil, "Tweenbrands", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn"]
        expect(sheet.row(1)).to eq ["Vendor Invoice", nil, nil, nil, nil, nil, nil, 40, nil, nil]
        expect(sheet.row(2)).to eq ["Entered Value", nil, nil, nil, nil, nil, nil, 20, nil, nil]
        expect(sheet.row(3)).to eq ["Duty Savings", nil, nil, nil, nil, nil, nil, 2, nil, nil]
        expect(sheet.row(4)).to eq ["Total Brand FOB Receipts", nil, nil, nil, nil, nil, nil, 40, nil, nil]
      end

      it "records Dress Barn first sale" do
        entry.commercial_invoice_lines.each {|line| line.update_attributes! contract_amount: 20, product_line: "DB" }
        tf = subject.run_report nil, {"fiscal_month" => "2017-03"}
        wb = XlsMaker.open_workbook(tf)

        sheet = wb.worksheet("First Sale")
        expect(sheet.rows.count).to eq 5
        expect(sheet.row(0)).to eq [nil, "Tweenbrands", nil, "Lane Bryant", nil, "Catherines", nil, "Maurices", nil, "Dressbarn"]
        expect(sheet.row(1)).to eq ["Vendor Invoice", nil, nil, nil, nil, nil, nil, nil, nil, 40]
        expect(sheet.row(2)).to eq ["Entered Value", nil, nil, nil, nil, nil, nil, nil, nil, 20]
        expect(sheet.row(3)).to eq ["Duty Savings", nil, nil, nil, nil, nil, nil, nil, nil, 2]
        expect(sheet.row(4)).to eq ["Total Brand FOB Receipts", nil, nil, nil, nil, nil, nil, nil, nil, 40]
      end
    end

  end

  
end
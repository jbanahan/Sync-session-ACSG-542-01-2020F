require 'spec_helper'

describe OpenChain::Report::JCrewBillingReport do

  describe "permission?" do
    it "allows access to master companies for www users" do
      MasterSetup.any_instance.should_receive(:system_code).and_return "www-vfitrack-net"
      expect(described_class.permission? Factory(:master_user)).to be_true
    end

    it "denies access to non-master users" do
      MasterSetup.any_instance.should_receive(:system_code).and_return "www-vfitrack-net"
      expect(described_class.permission? Factory(:user)).to be_false
    end

    it "denies access to non-www systems" do
      expect(described_class.permission? Factory(:master_user)).to be_false
    end
  end
  
  describe "run" do
    before :each do
      @entry = Factory(:commercial_invoice_tariff, duty_amount: BigDecimal.new("50"),
                          commercial_invoice_line: Factory(:commercial_invoice_line, po_number: "123", prorated_mpf: BigDecimal.new("1.50"), hmf: BigDecimal.new("2.25"), cotton_fee: BigDecimal.new("3.50"),
                            commercial_invoice: Factory(:commercial_invoice,
                              entry: Factory(:entry, total_fees: BigDecimal.new("9.99"), total_duty: BigDecimal.new("10.00"), entry_number: "12345")
                          )
                        )
                      ).commercial_invoice_line.commercial_invoice.entry

      line = Factory(:broker_invoice_line, charge_type: "R", charge_amount: BigDecimal.new("100"),
        broker_invoice: Factory(:broker_invoice, customer_number: 'JCREW', invoice_date: '2014-01-01', invoice_number: "Inv#", entry: @entry)
      )
      @r = OpenChain::Report::JCrewBillingReport.new 'start_date' => "2014-01-01".to_date, 'end_date' => "2014-01-01".to_date
    end

    after :each do
      @temp.close! if @temp
    end

    def column_values values
      v = []
      (0..17).each do |x|
        v << ((values[x]) ? values[x] : 0)
      end
      v
    end

    it "displays billing data for the given timeframe" do
      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0

      expect(s.row(0)).to eq ["Invoice #", "Invoice Date", "Entry #", "Direct Brokerage", "Direct Duty", "Retail Brokerage", "Retail Duty", "Factory Brokerage", "Factory Duty",
                "Factory Direct Brokerage", "Factory Direct Duty", "Madewell Direct Brokerage", "Madewell Direct Duty", "Madewell Retail Brokerage", "Madewell Retail Duty",
                "Retail T & E Brokerage", "Retail T & E Duty", "Madewell Factory Brokerage", "Madewell Factory Duty", "Madewell Wholesale Brokerage", "Madewell Wholesale Duty", "Total Brokerage", "Total Duty", "Errors"]

      expect(s.row(1)).to eq ["Inv#", excel_date("2014-01-01".to_date), "123-45", column_values(0=>100.0, 1=>57.25), 100.0, 19.99].flatten
    end

    it "identifies Madewell Wholesale PO's" do
      @entry.commercial_invoice_lines.first.update_attributes! po_number: "02123"
      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0

      expect(s.row(0)).to eq ["Invoice #", "Invoice Date", "Entry #", "Direct Brokerage", "Direct Duty", "Retail Brokerage", "Retail Duty", "Factory Brokerage", "Factory Duty",
                "Factory Direct Brokerage", "Factory Direct Duty", "Madewell Direct Brokerage", "Madewell Direct Duty", "Madewell Retail Brokerage", "Madewell Retail Duty",
                "Retail T & E Brokerage", "Retail T & E Duty", "Madewell Factory Brokerage", "Madewell Factory Duty", "Madewell Wholesale Brokerage", "Madewell Wholesale Duty", "Total Brokerage", "Total Duty", "Errors"]

      expect(s.row(1)).to eq ["Inv#", excel_date("2014-01-01".to_date), "123-45", column_values(16=>100.0, 17=>57.25), 100.0, 19.99].flatten
    end

    it "splits brokerage charges into multiple buckets prorating by PO # counts" do
      # This should give us a total of 6 unique lines, using 100 split 6 ways is a perfect test for the proration algorithm too
      # since the 3rd po is a 1/6th proration (16.66) vs. a 1/3 proration (33.33) and it should dump the leftover cent into the highest
      # valued truncated amount (ie. the 16.66 one)
      @entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "122"
      @entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "133"
      @entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "222"
      @entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "223"
      @entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "324"

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["Inv#", excel_date("2014-01-01".to_date), "123-45", column_values(0=>50.00, 1=>57.25, 2=>33.33, 4=>16.67), 100.0, 19.99].flatten
    end

    it "sets all charges for a T/E entry into their own bucket" do
      @entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_code: '0910'
      @entry.broker_invoices.first.broker_invoice_lines.create! charge_amount: BigDecimal.new("100"), charge_description: "Blank", charge_code: "123", charge_type: "R"

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["Inv#", excel_date("2014-01-01".to_date), "123-45", column_values(1=> 57.25, 12=>200.0), 200.0, 19.99].flatten
    end

    it "identifies and highlights invalid PO numbers" do
      l = @entry.commercial_invoices.first.commercial_invoice_lines.create! po_number: "Invalid"
      l.commercial_invoice_tariffs.create! duty_amount: 10

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["Inv#", excel_date("2014-01-01".to_date), "123-45", column_values(0=>50.00, 1=>57.25), 100.0, 19.99, "Invalid PO #: Invalid. Unallocated Charges: 50.0. Unallocated Duty: 10.0."].flatten

      # Verify we've highlighted the bad row
      expect(s.row(1).format(0).pattern_fg_color).to eq :yellow
    end

    it "sums all invoices found in date range, excludes those outside of range" do
      @entry.broker_invoices.first.update_attributes! invoice_date: '2013-01-01'

      inv2 = @entry.broker_invoices.create! invoice_number: "2", invoice_date: '2014-01-01', customer_number: "J0000"
      inv2.broker_invoice_lines.create! charge_amount: BigDecimal.new("100"), charge_description: "Blank", charge_code: "123", charge_type: "R"

      inv3 = @entry.broker_invoices.create! invoice_number: "3", invoice_date: '2014-01-01', customer_number: "CREWFTZ"
      inv3.broker_invoice_lines.create! charge_amount: BigDecimal.new("100"), charge_description: "Blank", charge_code: "123", charge_type: "R"      

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["2", excel_date("2014-01-01".to_date), "123-45", column_values(0=>200), 200.0, 0].flatten
    end

    it "doesn't add entry information when invoice amounts for the date range zero each other out" do
      inv2 = @entry.broker_invoices.create! invoice_number: "2", invoice_date: '2014-01-01', customer_number: "J0000"
      inv2.broker_invoice_lines.create! charge_amount: BigDecimal.new("-100"), charge_description: "Blank", charge_code: "123", charge_type: "R"

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["No billing data returned for this report."]
    end

    it "shows a message if no data found" do
      @entry.broker_invoices.first.update_attributes! invoice_date: '2013-01-01'

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["No billing data returned for this report."]
    end

    it "ignores charge codes over 1000" do
      @entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_code: 1001

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["No billing data returned for this report."]
    end

    it "ignores lines with 'COST' in description" do
      @entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_description: "COST"

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["No billing data returned for this report."]
    end

    it "ignores lines with 'FREIGHT' in description" do
      @entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_description: "FREIGHT"

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["No billing data returned for this report."]
    end

    it "ignores lines with 'DUTY' in description" do
      @entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_description: "DUTY"

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["No billing data returned for this report."]
    end

    it "ignores lines with 'WAREHOUSE' in description" do
      @entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_description: "WAREHOUSE"

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["No billing data returned for this report."]
    end

    it "ignores lines with charge codes in massive exclusion list" do
      @entry.broker_invoices.first.broker_invoice_lines.first.update_attributes! charge_code: 999

      @temp = @r.run
      s = Spreadsheet.open(@temp.path).worksheet 0
      expect(s.row(1)).to eq ["No billing data returned for this report."]
    end
  end
end
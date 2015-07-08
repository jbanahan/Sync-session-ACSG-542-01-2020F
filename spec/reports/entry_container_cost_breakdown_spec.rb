require 'spec_helper'

describe OpenChain::Report::EntryContainerCostBreakdown do

  context "with entry data" do
    before :each do
      @tariff = Factory(:commercial_invoice_tariff, duty_amount: 10, commercial_invoice_line: Factory(:commercial_invoice_line, value: 20, hmf: 30, mpf: 40))
      @line = @tariff.commercial_invoice_line
      @tariff2 = Factory(:commercial_invoice_tariff, duty_amount: 15, commercial_invoice_line: @line)
      @entry = @line.entry
      @entry.update_attributes! customer_number: "CQ", release_date: "2015-06-01", master_bills_of_lading: "MBOL", entry_number: "EN12345"

      @tariff3 = Factory(:commercial_invoice_tariff, duty_amount: 10,
                          commercial_invoice_line: Factory(:commercial_invoice_line, value: 10, hmf: 20, mpf: 30, 
                                                            commercial_invoice: Factory(:commercial_invoice, entry: @entry)))
      @line2 = @tariff3.commercial_invoice_line

      @container1 = Factory(:container, entry: @entry, commercial_invoice_lines: [@line])
      @container2 = Factory(:container, entry: @entry, commercial_invoice_lines: [@line2])
      
      @broker_invoice_line = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: @entry, invoice_total: 50), charge_amount: 50)
      @broker_invoice = @broker_invoice_line.broker_invoice

      # Create a freight charge
      @broker_invoice_line_freight = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: @entry), charge_amount: 50, charge_code: '0600')
      @broker_invoice_freight = @broker_invoice_line_freight.broker_invoice

      @user = Factory(:master_user, time_zone: "UTC", entry_view: true)
      # By defualt, just allow access to all entrie (t)
      Entry.any_instance.stub(:can_view?).with(@user).and_return true
    end

    describe "run" do 
      it "lists container costs for an entry" do
        wb = subject.run @user, {'start_date' => '2015-06-01', 'end_date' => '2015-06-02', 'customer_number' => "CQ"}
        expect(wb).not_to be_nil

        wb = Spreadsheet.open(wb.path)
        sheet = wb.worksheet "06-01-15 - 06-01-15"
        expect(sheet).not_to be_nil

        expect(sheet.row(0)).to eq ["Bill Of Lading", "Container Number", "Entry Number", "Freight", "Duty", "HMF", "MPF", "Commercial Invoice Value", "Brokerage Fees", "Total"]
        expect(sheet.row(1)).to eq ["MBOL", @container1.container_number, "EN12345", BigDecimal("25"), BigDecimal("25"), BigDecimal("30"), BigDecimal("40"), BigDecimal("20"), BigDecimal("25"), BigDecimal("165")]
        expect(sheet.row(2)).to eq ["MBOL", @container2.container_number, "EN12345", BigDecimal("25"), BigDecimal("10"), BigDecimal("20"), BigDecimal("30"), BigDecimal("10"), BigDecimal("25"), BigDecimal("120")]
        expect(sheet.row(3)).to eq []
      end

      it "assigns freight costs per container based on the charge description" do
        # assign the freight cost for our freight charge line to a single container
        @broker_invoice_line_freight.update_attributes! charge_description: @container1.container_number
        wb = subject.run @user, {'start_date' => '2015-06-01', 'end_date' => '2015-06-02', 'customer_number' => "CQ"}
        wb = Spreadsheet.open(wb.path)
        sheet = wb.worksheet "06-01-15 - 06-01-15"

        expect(sheet.row(1)).to eq ["MBOL", @container1.container_number, "EN12345", BigDecimal("50"), BigDecimal("25"), BigDecimal("30"), BigDecimal("40"), BigDecimal("20"), BigDecimal("25"), BigDecimal("190")]
        expect(sheet.row(2)).to eq ["MBOL", @container2.container_number, "EN12345", BigDecimal("0"), BigDecimal("10"), BigDecimal("20"), BigDecimal("30"), BigDecimal("10"), BigDecimal("25"), BigDecimal("95")]
      end

      it "sums values together for whole entry if no containers are present" do
        # This would occur for non-containerized shipments (which we still want to list out on the report)
        @entry.containers.destroy_all

        wb = subject.run @user, {'start_date' => '2015-06-01', 'end_date' => '2015-06-02', 'customer_number' => "CQ"}
        wb = Spreadsheet.open(wb.path)
        sheet = wb.worksheet "06-01-15 - 06-01-15"

        expect(sheet.row(1)).to eq ["MBOL", nil, "EN12345", BigDecimal("50"), BigDecimal("35"), BigDecimal("50"), BigDecimal("70"), BigDecimal("30"), BigDecimal("50"), BigDecimal("285")]
        expect(sheet.row(2)).to eq []
      end

      it "progressively distributes remainder of unevenly divided freight and brokerage sums across all containers" do
        # In other words...
        # 3 containers, $80 charge 
          # -> Container 1 = 26.67, Container 2 = 26.67, Container 3 = 26.66
          # NOT ->  Container 1 = 26.68, Container 2 = 26.66, Container 3 = 26.66
        @broker_invoice.update_attributes! invoice_total: 80
        @broker_invoice_line_freight.update_attributes! charge_amount: 80
        # Add a 3rd container to affect the proration we're expecting
        @entry.containers.create! container_number: "ABC123"

        wb = subject.run @user, {'start_date' => '2015-06-01', 'end_date' => '2015-06-02', 'customer_number' => "CQ"}
        wb = Spreadsheet.open(wb.path)
        sheet = wb.worksheet "06-01-15 - 06-01-15"

        # All we care about is the freight and brokerage amounts for this test
        expect(sheet.row(1)[3]).to eq BigDecimal("26.67")
        expect(sheet.row(2)[3]).to eq BigDecimal("26.67")
        expect(sheet.row(3)[3]).to eq BigDecimal("26.66")

        expect(sheet.row(1)[8]).to eq BigDecimal("26.67")
        expect(sheet.row(2)[8]).to eq BigDecimal("26.67")
        expect(sheet.row(3)[8]).to eq BigDecimal("26.66")
      end 

      it "excludes entries ouside of given timeframe" do
        # Test whether we're applying timezone manipulation or not
        # User is GMT timezone, so if we set the release date to 11PM on the eve of the end_date param
        # we shouldn't get any results, since for the user this is outside his/her given timeframe
        @entry.update_attributes! release_date: ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2015-06-01 23:00")

        wb = subject.run @user, {'start_date' => '2015-06-01', 'end_date' => '2015-06-02', 'customer_number' => "CQ"}
        wb = Spreadsheet.open(wb.path)
        sheet = wb.worksheet "06-01-15 - 06-01-15"
        expect(sheet.row(1)).to eq []
      end

      it "excludes entries user does not have access to" do
        # a blank user will not have entries returned by the query
        wb = subject.run Factory(:user, time_zone: "UTC"), {'start_date' => '2015-06-01', 'end_date' => '2015-06-02', 'customer_number' => "CQ"}
        wb = Spreadsheet.open(wb.path)
        sheet = wb.worksheet "06-01-15 - 06-01-15"
        expect(sheet.row(1)).to eq []
      end

      it "excludes entries user cannot view" do
        Entry.any_instance.stub(:can_view?).with(@user).and_return false
        wb = subject.run @user, {'start_date' => '2015-06-01', 'end_date' => '2015-06-02', 'customer_number' => "CQ"}
        wb = Spreadsheet.open(wb.path)
        sheet = wb.worksheet "06-01-15 - 06-01-15"
        expect(sheet.row(1)).to eq []
      end
    end 

    describe "run_report" do
      it "runs the report" do
        # validate the data is present, don't bother validating the actual data though, we've done that already
        wb = subject.run @user, {'start_date' => '2015-06-01', 'end_date' => '2015-06-02', 'customer_number' => "CQ"}
        expect(wb).not_to be_nil

        wb = Spreadsheet.open(wb.path)
        sheet = wb.worksheet 0
        expect(sheet).not_to be_nil
      end
    end
  end

  

end
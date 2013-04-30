require 'spec_helper'

describe OpenChain::Report::KitchenCraftBillingReport do

  context :run do
    before :each do
      @entry = Factory(:entry, :customer_number=>'KITCHEN', :release_date=>Time.zone.now, :broker_reference=>'99123456', :entry_number => '1231kl0', :po_numbers => "123\n456", \
        :carrier_code=>'SCAC', :master_bills_of_lading=>"abc\n123", :container_numbers=>"1\n2", :total_invoiced_value=>100)
      @invoices = []
      @charges = []
      ['Invoice1', 'Invoice2'].each do |inv_num| 
        invoice = Factory(:broker_invoice, :entry_id=>@entry.id, :invoice_total => 100, :invoice_number => inv_num)
        @invoices << invoice

        ['0001', '0009', '0008', '0220', '0007', '0162', '0198', '0022', '0221', '0222'].each do |code|
          #Create 2 charges for each invoice, just so we know we're summing the data correctly
          @charges << Factory(:broker_invoice_line, :broker_invoice_id=>invoice.id, :charge_code=> code, :charge_amount=>25.50)
          @charges << Factory(:broker_invoice_line, :broker_invoice_id=>invoice.id, :charge_code=> code, :charge_amount=>20)
        end
      end
    end

    it 'should create a worksheet with invoice billing data' do
      tmp = OpenChain::Report::KitchenCraftBillingReport.run_report nil, {'start_date' => Time.zone.now.strftime("%Y-%m-%d"), 'end_date'=>(Time.zone.now + 1.day).strftime("%Y-%m-%d")}
      wb = Spreadsheet.open tmp
      sheet = wb.worksheet 0
      sheet.row(0).should == ['FILE NO', 'FILER CODE', 'Entry NO', 'CUST. REF', 'SCAC', 'MASTER BILLS', 'CONTAINER NOs', 'RELEASE DATE', 'VALUE ENTERED', 'DUTY', 'ADDITIONAL CLASSIFICATIONS', 'ADDITIONAL INVOICES', 'BORDER CLEARANCE', 'CUSTOMS ENTRY', 'DISBURSEMENT FEES', 'LACEY ACT FILING', 'MISSING DOCUMENTS', 'OBTAIN IRS NO.', 'OBTAIN IRS NO. CF FROM 5106', 'BILLED TO-DATE']
      # All the charge columns will add up to the same exact value (that's just how they're set up)
      sheet.row(1).should == [@entry.broker_reference, @entry.entry_number[0, 3], @entry.entry_number[3..-1], @entry.po_numbers.gsub("\n", ", "), @entry.carrier_code, @entry.master_bills_of_lading.gsub("\n", ", "), \
                              @entry.container_numbers.gsub("\n", ", "), excel_date(@entry.release_date.to_date), @entry.total_invoiced_value, 91, 91, 91, 91, 91, 91, 91, 91, 91, 91, 200]
    end

    it 'should handle different user timezones in input and output' do
      # The DB dates are UTC, so make sure we're translating the start date / end date value 
      # to the correct UTC equiv

      # Update the release date to a time we know will be 1 day in the future in UTC vs. local timezone
      release_date = Time.new(2013, 4, 1, 5, 0, 0, "+00:00")
      @entry.update_attributes :release_date => release_date
      sheet = nil
      
      Time.use_zone(ActiveSupport::TimeZone['Hawaii']) do
        tmp = OpenChain::Report::KitchenCraftBillingReport.run_report nil, {'start_date' => '2013-03-31', 'end_date'=>'2013-04-01'}
        wb = Spreadsheet.open tmp
        sheet = wb.worksheet 0
      end

      sheet.row(1)[7].should == Date.new(2013, 3, 31)
    end
  end
end
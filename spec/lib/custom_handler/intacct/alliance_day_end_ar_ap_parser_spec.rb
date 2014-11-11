require 'spec_helper'

describe OpenChain::CustomHandler::Intacct::AllianceDayEndArApParser do

  describe "extract_invoices" do
    it "reads invoices from day end file" do
      file = <<FILE
---------- -- ---- ----- -------- ---------- ------------- --------- ---------- --------------- ---  --  ---  ---  ---  ---  --- --
    571606       4 0099* 08/12/14            316-05716062            VFFTZ          390,120.41  USD  D    Y    N    N    F    N  N
    571606       4 0007  08/12/14                          0400-0004 VFFTZ              500.00  USD  R    Y    N    N    F    N  N

Inv. Total:         500.00   A/P Total:             .00   Verification Total:             .00
------------------------------------------------------------------------------------------------------------------------------------
   1544953 V    15 0200  08/12/14            EE408173      0416-0015 NEXEO              640.00- USD  C    Y    N    N    F    N  N
   1544953 V    15 0201  08/12/14 BTRAN      MEDU1088180   0617-0015 NEXEO              640.00- USD  C    N    N    Y    F    N  N

Inv. Total:         640.00-  A/P Total:          640.00-  Verification Total:             .00
---------- -- ---- ----- -------- ---------- ------------- --------- ---------- --------------- ---  --  ---  ---  ---  ---  --- --
                                       **** G R A N D   T O T A L S ****
Inv. Total:     987,654.32   A/P Total:      123,456.78   Verification Total:      864,197.54

------------------------------------------------------------------------------------------------------------------------------------
   2234059 V    10 0099* 08/12/14            316-22340599            PVH             83,178.63- USD  D    Y    N    N    F    N
   2234059 V    10 0007  08/12/14            065826502     0400-0010 PVH                 80.00- USD  R    Y    N    N    F    N
   2234059 V    10 0191  08/12/14            065826502     0400-0010 PVH                 15.00- USD  R    Y    N    N    F    N

Inv. Total:          95.00-  A/P Total:             .00   Verification Total:             .00
FILE

      # The invoice after the GRAND TOTALS line is skipped because (for some reason), Alliance sends all credit invoices twice,
      # grouping the credit invoices in w/ the normal ones and then including them all again at the end of the file

      invoice_info = described_class.new.extract_invoices StringIO.new(file)
      # This just shows the totals are parsed from the actual totals line in the file,
      # not summing the invoices
      
      expect(invoice_info[:ar_grand_total]).to eq BigDecimal.new("987654.32")
      expect(invoice_info[:ap_grand_total]).to eq BigDecimal.new("123456.78")

      expect(invoice_info.keys).to eq [:ar_grand_total, :ap_grand_total, "571606", "1544953V"]
      inv_info = invoice_info["571606"]
      expect(inv_info[:ar_total]).to eq BigDecimal.new("500")
      expect(inv_info[:ap_total]).to eq BigDecimal.new("0")
      expect(inv_info[:lines].length).to eq 1


      info = inv_info[:lines].first
      expect(info[:invoice_number]).to eq "571606"
      expect(info[:suffix]).to eq ""
      expect(info[:division]).to eq "4"
      expect(info[:invoice_date]).to eq Date.new 2014, 8, 12
      expect(info[:vendor]).to eq ""
      expect(info[:vendor_reference]).to eq ""
      expect(info[:customer_number]).to eq "VFFTZ"
      expect(info[:amount]).to eq BigDecimal.new "500"
      expect(info[:currency]).to eq "USD"
      expect(info[:a_r]).to eq "Y"
      expect(info[:a_p]).to eq "N"


      inv_info = invoice_info["1544953V"]
      expect(inv_info[:ar_total]).to eq BigDecimal.new("-640")
      expect(inv_info[:ap_total]).to eq BigDecimal.new("-640")
      expect(inv_info[:lines].length).to eq 2
      info = inv_info[:lines].first
      expect(info[:invoice_number]).to eq "1544953"
      expect(info[:suffix]).to eq "V"
      expect(info[:division]).to eq "15"
      expect(info[:invoice_date]).to eq Date.new 2014, 8, 12
      expect(info[:vendor]).to eq ""
      expect(info[:vendor_reference]).to eq "EE408173"
      expect(info[:customer_number]).to eq "NEXEO"
      expect(info[:amount]).to eq BigDecimal.new "-640.00"
      expect(info[:currency]).to eq "USD"
      expect(info[:a_r]).to eq "Y"
      expect(info[:a_p]).to eq "N"

      info = inv_info[:lines].second
      expect(info[:invoice_number]).to eq "1544953"
      expect(info[:suffix]).to eq "V"
      expect(info[:division]).to eq "15"
      expect(info[:invoice_date]).to eq Date.new 2014, 8, 12
      expect(info[:vendor]).to eq "BTRAN"
      expect(info[:vendor_reference]).to eq "MEDU1088180"
      expect(info[:customer_number]).to eq "NEXEO"
      expect(info[:amount]).to eq BigDecimal.new "-640.00"
      expect(info[:currency]).to eq "USD"
      expect(info[:a_r]).to eq "N"
      expect(info[:a_p]).to eq "Y"
    end
  end

  describe "create_and_request_invoice" do

    before :each do
      @client = double("OpenChain::SqlProxyClient")
      @client.stub(:delay).and_return @client
      @invoice_data = inv_data = {
        ar_total: BigDecimal.new("123.45"), 
        ap_total: BigDecimal.new("987.65"),
        lines: [
          {invoice_number: "123", suffix: "", division: "DIV", invoice_date: Date.new(2014, 11, 1), customer_number: "CUST"}
        ]
      }
    end

    it "creates alliance export objects from parsed invoice info" do
      @client.should_receive(:request_alliance_invoice_details).with "123", nil
      export, errors = described_class.new.create_and_request_invoice @invoice_data, @client

      expect(errors.length).to eq 0
      expect(export).to be_persisted
      expect(export.file_number).to eq "123"
      expect(export.suffix).to be_nil
      expect(export.export_type).to eq IntacctAllianceExport::EXPORT_TYPE_INVOICE
      expect(export.division).to eq "DIV"
      expect(export.invoice_date).to eq Date.new(2014, 11, 1)
      expect(export.customer_number).to eq "CUST"
      expect(export.ar_total).to eq BigDecimal.new("123.45")
      expect(export.ap_total).to eq BigDecimal.new("987.65")
      expect(export.data_received_date).to be_nil
      expect(export.data_requested_date.to_date).to eq Time.zone.now.to_date
    end

    it "updates existing alliance exports" do
      @client.should_receive(:request_alliance_invoice_details).with "123", "A"
      @invoice_data[:lines].first[:suffix] = "A"
      existing = IntacctAllianceExport.create! file_number: "123", suffix: "A", export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE, data_received_date: Time.now

      export, errors = described_class.new.create_and_request_invoice @invoice_data, @client

      expect(errors.length).to eq 0
      expect(export).to be_persisted
      expect(export).to eq existing
      expect(export.data_received_date).to be_nil
    end

    it "errors if an invoice associated w/ the export has been uploaded to intacct" do
      IntacctReceivable.create! invoice_number: "123", company: 'vfc', intacct_upload_date: Time.zone.now, intacct_key: "KEY"

      export, errors = described_class.new.create_and_request_invoice @invoice_data, @client
      expect(export).to be_nil
      expect(errors).to eq ["An invoice and/or bill has already been filed in Intacct for File # 123."]
    end

    it "errors if a payable invoice associated w/ the export has been uploaded to intacct" do
      @invoice_data[:lines].first[:suffix] = "A"
      IntacctPayable.create! bill_number: "123A", company: 'lmd', intacct_upload_date: Time.zone.now, intacct_key: "KEY"

      export, errors = described_class.new.create_and_request_invoice @invoice_data, @client
      expect(export).to be_nil
      expect(errors).to eq ["An invoice and/or bill has already been filed in Intacct for File # 123A."]
    end
  end

  describe "validate_invoice_data" do
    it "confirms each invoice matches given ap/ar totals and sum of invoices matches expected grand totals" do
      inv_data = {
        "123" => {
          ar_total: BigDecimal.new("123.45"), 
          ap_total: BigDecimal.new("987.65"),
          lines: [
            {invoice_number: "123", suffix: "", division: "DIV", invoice_date: Date.new(2014, 11, 1), customer_number: "CUST", a_r: "Y", a_p: "N", amount: BigDecimal.new("100.00")},
            {invoice_number: "123", suffix: "", division: "DIV", invoice_date: Date.new(2014, 11, 1), customer_number: "CUST", a_r: "Y", a_p: "Y", amount: BigDecimal.new("23.45")},
            {invoice_number: "123", suffix: "", division: "DIV", invoice_date: Date.new(2014, 11, 1), customer_number: "CUST", a_r: "N", a_p: "Y", amount: BigDecimal.new("964.20")}
          ]
        },
        "456A" => {
          ar_total: BigDecimal.new("10.00"), 
          ap_total: BigDecimal.new("10.00"),
          lines: [
            {invoice_number: "456", suffix: "A", division: "DIV", invoice_date: Date.new(2014, 11, 1), customer_number: "CUST", a_r: "Y", a_p: "Y", amount: BigDecimal.new("10.00")}
          ]
        },
        :ar_grand_total => BigDecimal.new("133.45"),
        :ap_grand_total => BigDecimal.new("997.65")
      }
      expect(described_class.new.validate_invoice_data(inv_data).size).to eq 0
    end

    it "errors on invalid invoice sums" do
      inv_data = {
        "123" => {
          ar_total: BigDecimal.new("123.45"), 
          ap_total: BigDecimal.new("987.65"),
          lines: [
            {invoice_number: "123", suffix: "", division: "DIV", invoice_date: Date.new(2014, 11, 1), customer_number: "CUST", a_r: "Y", a_p: "Y", amount: BigDecimal.new(1)}
          ]
        },
        :ar_grand_total => BigDecimal.new("7894"),
        :ap_grand_total => BigDecimal.new("1231123.56")
      }

      errors = described_class.new.validate_invoice_data inv_data
      expect(errors.size).to eq 4
      expect(errors).to include "Expected A/R Amount for Invoice # 123 to be $123.45.  Found $1.00."
      expect(errors).to include "Expected A/P Amount for Invoice # 123 to be $987.65.  Found $1.00."
      expect(errors).to include "Expected Grand Total A/R Amount to be $7,894.00.  Found $1.00."
      expect(errors).to include "Expected Grand Total A/P Amount to be $1,231,123.56.  Found $1.00."
    end
  end
end
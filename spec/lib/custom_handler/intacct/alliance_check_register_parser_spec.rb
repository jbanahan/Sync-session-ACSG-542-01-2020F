require 'spec_helper'

describe OpenChain::CustomHandler::Intacct::AllianceCheckRegisterParser do
  describe "extract_check_info" do
    it "extracts check info from file" do
      file = <<-FILE
---------- ---------- ------------  ---------- ---------- --- --------- ------------ ------------- ---------- ---- -------------  --
      9801 KINGOCEAN     1615657A              IGM        F   0202-0000 LIOPEV12468      2,295.00  08/12/2014 Adv                 AP
           KING OCEAN SERVICES         Total of Check       9801                         2,295.00

                                                   5 Checks for Bank 02 Totaling         1,234.00
---------- ---------- ------------  ---------- ---------- --- --------- ------------ ------------- ---------- ---- -------------  --
     *****  Grand Total  *****                           Record Count:    108          109,275.95

FILE
      check_info = described_class.new.extract_check_info StringIO.new(file)

      expect(check_info[:total_check_count]).to eq 108
      expect(check_info[:total_check_amount]).to eq BigDecimal.new("109275.95")

      bank_check_info = check_info[:checks]["2"]
      expect(bank_check_info[:check_count]).to eq 5
      expect(bank_check_info[:check_total]).to eq BigDecimal.new("1234.00")
      checks = bank_check_info[:checks]
      expect(checks.length).to eq 1

      check = checks.first
      expect(check[:bank_number]).to eq "2"
      expect(check[:check_number]).to eq "9801"
      expect(check[:vendor_number]).to eq "KINGOCEAN"
      expect(check[:invoice_number]).to eq "1615657"
      expect(check[:invoice_suffix]).to eq "A"
      expect(check[:customer_number]).to eq "IGM"
      expect(check[:vendor_reference]).to eq "LIOPEV12468"
      expect(check[:check_amount]).to eq BigDecimal.new("2295.00")
      expect(check[:check_date]).to eq Date.new(2014, 8, 12)
    end
  end

  describe "validate_check_info" do
    it "validates check info is internally consistent" do
      check_info = {
        :total_check_count => 2,
        :total_check_amount => BigDecimal.new("100.00"),
        :checks => {
          "2" => {
            check_count: 2,
            check_total: BigDecimal.new("100.00"),
            checks: [
              {check_amount: BigDecimal.new("25.00")},
              {check_amount: BigDecimal.new("75.00")}
            ]
          }
        }
      }

      errors = described_class.new.validate_check_info check_info
      expect(errors.size).to eq 0
    end

    it "raises an error if total count is missing" do
      expect{described_class.new.validate_check_info({})}.to raise_error "No Check Register Record Count found."
    end

    it "raises an error if total check amount is missing" do
      expect{described_class.new.validate_check_info({total_check_count: 1})}.to raise_error "No Check Register Grand Total amount found."
    end

    it "returns errors when check info is not internally consistent" do
      check_info = {
        :total_check_count => 6,
        :total_check_amount => BigDecimal.new("400.00"),
        :checks => {
          "2" => {
            check_count: 4,
            check_total: BigDecimal.new("200.00"),
            checks: [
              {check_amount: BigDecimal.new("25.00")},
              {check_amount: BigDecimal.new("75.00")}
            ]
          }
        }
      }

      errors = described_class.new.validate_check_info check_info
      expect(errors.size).to eq 4
      expect(errors).to include "Expected 4 checks for Bank 02.  Found 2 checks."
      expect(errors).to include "Expected Check Total Amount of $200.00 for Bank 02.  Found $100.00."
      expect(errors).to include "Expected 6 checks to be in the register file.  Found 2 checks."
      expect(errors).to include "Expected Grand Total of $400.00 to be in the register file.  Found $100.00."
    end
  end

  describe "create_and_request_check" do
    before :each do
      @check_info = {
        check_number: "987", vendor_number: "VEND", invoice_number: "123", invoice_suffix: "", customer_number: "CUST",
        vendor_reference: "VEND_REF", check_amount: BigDecimal.new("100.00"), check_date: Date.new(2014, 11, 1), bank_number: "1"
      }
      @sql_proxy_client = double("OpenChain::SqlProxyClient")
      @sql_proxy_client.stub(:delay).and_return @sql_proxy_client
    end
    it "creates a check and export object" do
      xref = DataCrossReference.create! key: @check_info[:bank_number], value: "1234", cross_reference_type: DataCrossReference::INTACCT_BANK_CASH_GL_ACCOUNT

      @sql_proxy_client.should_receive(:request_check_details).with @check_info[:invoice_number], @check_info[:check_number], @check_info[:check_date], @check_info[:bank_number]
      check, errors = described_class.new.create_and_request_check @check_info, @sql_proxy_client
      expect(errors.length).to eq 0

      expect(check).to be_persisted
      expect(check.file_number).to eq @check_info[:invoice_number]
      expect(check.suffix).to be_nil
      expect(check.check_number).to eq @check_info[:check_number]
      expect(check.check_date).to eq @check_info[:check_date]
      expect(check.bank_number).to eq @check_info[:bank_number]
      expect(check.customer_number).to eq @check_info[:customer_number]
      expect(check.bill_number).to eq @check_info[:invoice_number]
      expect(check.vendor_number).to eq @check_info[:vendor_number]
      expect(check.vendor_reference).to eq @check_info[:vendor_reference]
      expect(check.amount).to eq @check_info[:check_amount]
      expect(check.gl_account).to eq "2021"
      expect(check.bank_cash_gl_account).to eq xref.value

      export = check.intacct_alliance_export
      expect(export).to be_persisted

      expect(export.customer_number).to eq @check_info[:customer_number]
      expect(export.data_requested_date.to_date).to eq Time.zone.now.to_date
      expect(export.data_received_date).to be_nil
      expect(export.ap_total).to eq check.amount
      expect(export.invoice_date).to eq check.check_date
      expect(export.check_number).to eq check.check_number
    end

    it "updates existing check / export objects" do
      @check_info[:invoice_suffix] = "A"
      existing_check = IntacctCheck.create! file_number: @check_info[:invoice_number], suffix: @check_info[:invoice_suffix], check_number: @check_info[:check_number], check_date: @check_info[:check_date], bank_number: @check_info[:bank_number]
      existing_export = IntacctAllianceExport.create! file_number: @check_info[:invoice_number], suffix: @check_info[:invoice_suffix], check_number: @check_info[:check_number], export_type: IntacctAllianceExport::EXPORT_TYPE_CHECK, data_received_date: Time.zone.now

      @sql_proxy_client.should_receive(:request_check_details).with @check_info[:invoice_number], @check_info[:check_number], @check_info[:check_date], @check_info[:bank_number]
      check, errors = described_class.new.create_and_request_check @check_info, @sql_proxy_client
      expect(errors.length).to eq 0

      expect(check).to eq existing_check
      expect(check.intacct_alliance_export).to eq existing_export
      expect(check.intacct_alliance_export.data_received_date).to be_nil
    end

    it "errors if a payable for the same file number has already been sent to intacct" do
      @check_info[:invoice_suffix] = "A"
      bill_number = @check_info[:invoice_number]+@check_info[:invoice_suffix]
      IntacctPayable.create! bill_number: bill_number, vendor_number: @check_info[:vendor_number], intacct_upload_date: Time.zone.now, intacct_key: "Key"

      check, errors = described_class.new.create_and_request_check @check_info, nil
      expect(check).to be_nil
      expect(errors.length).to eq 1
      expect(errors).to include "An invoice has already been filed in Intacct for File # #{bill_number}.  Check # #{@check_info[:check_number]} must be filed manually in Intacct."
    end

    it "errors if check has already been sent to intacct" do
      @check_info[:invoice_suffix] = "A"
      IntacctCheck.create! file_number: @check_info[:invoice_number], suffix: @check_info[:invoice_suffix], check_number: @check_info[:check_number], check_date: @check_info[:check_date], bank_number: @check_info[:bank_number], intacct_upload_date: Time.zone.now, intacct_key: "Key"
      check, errors = described_class.new.create_and_request_check @check_info, nil
      expect(check).to be_nil
      expect(errors.length).to eq 1
      expect(errors).to include "Check # #{@check_info[:check_number]} has already been sent to Intacct."
    end
  end
end
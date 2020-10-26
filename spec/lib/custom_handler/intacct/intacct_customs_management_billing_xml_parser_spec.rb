describe OpenChain::CustomHandler::Intacct::IntacctCustomsManagementBillingXmlParser do

  describe "parse" do

    let (:xml_data) { IO.read 'spec/fixtures/files/cmus_billing_file.xml'}
    let (:document) { Nokogiri::XML(xml_data) }
    let! (:inbound_file) do
      f = InboundFile.new
      allow(subject).to receive(:inbound_file).and_return f
      f
    end
    let! (:gl_account_xref) { DataCrossReference.create! key: "0007", value: "1234", cross_reference_type: "al_gl_code" }
    let (:existing_export) { IntacctAllianceExport.create! file_number: "2529468", suffix: "A", export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE }
    let (:existing_receivable) { existing_export.intacct_receivables.create! invoice_number: "2529468A" }
    let (:existing_payable) { existing_export.intacct_payables.create! bill_number: "2529468A", vendor_number: "VENDOR" }

    it "parses billing data into receivable and payables" do
      now = Time.zone.parse('2020-05-08 12:30:30')
      expect(OpenChain::CustomHandler::Intacct::IntacctDataPusher).to receive(:delay).and_return OpenChain::CustomHandler::Intacct::IntacctDataPusher
      delayed_id = nil
      expect(OpenChain::CustomHandler::Intacct::IntacctDataPusher).to receive(:push_billing_export_data) do |id|
        delayed_id = id
      end

      Timecop.freeze(now) do
        expect { subject.parse document }.to change(IntacctAllianceExport, :count).from(0).to(1)
      end

      export = IntacctAllianceExport.first
      expect(delayed_id).to eq export.id
      expect(export.shipment_number).to eq "2529468"
      expect(export.broker_reference).to eq "2529468"
      expect(export.file_number).to eq "2529468"
      expect(export.suffix).to eq "A"
      expect(export.division).to eq "10"
      expect(export.customer_number).to eq "TALBO"
      expect(export.shipment_customer_number).to eq "STALBO"
      expect(export.invoice_date).to eq Date.new(2020, 4, 7)
      expect(export.ar_total).to eq BigDecimal("85")
      expect(export.ap_total).to eq BigDecimal("85")
      expect(export.data_requested_date).to eq now
      expect(export.data_received_date).to eq now

      expect(export.intacct_receivables.length).to eq 1

      ir = export.intacct_receivables.first
      expect(ir.currency).to eq "USD"
      expect(ir.invoice_number).to eq "2529468A"
      expect(ir.company).to eq "vfc"
      expect(ir.invoice_date).to eq Date.new(2020, 4, 7)
      expect(ir.customer_number).to eq "TALBO"
      expect(ir.shipment_customer_number).to eq "STALBO"
      expect(ir.receivable_type).to eq "VFI Sales Invoice"
      expect(ir.intacct_errors).to be_nil
      expect(ir.intacct_upload_date).to be_nil

      # There's 3 lines on the XML, but 1 is suppressed and 1 is an offsetting (DUTY)
      # due to there being a Duty Paid Direct line on it.
      expect(ir.intacct_receivable_lines.length).to eq 1
      rl = ir.intacct_receivable_lines.first

      expect(rl.amount).to eq BigDecimal("85")
      expect(rl.location).to eq "10"
      expect(rl.charge_code).to eq "0007"
      expect(rl.charge_description).to eq "CUSTOMS ENTRY"
      expect(rl.broker_file).to eq "2529468"
      expect(rl.line_of_business).to eq "Brokerage"
      expect(rl.vendor_number).to eq "VENDOR"
      expect(rl.vendor_reference).to eq "REFERENCE"

      expect(export.intacct_payables.length).to eq 1

      ip = export.intacct_payables.first
      expect(ip.bill_number).to eq "2529468A"
      expect(ip.vendor_number).to eq "VENDOR"
      expect(ip.payable_type).to eq "bill"
      expect(ip.bill_date).to eq Date.new(2020, 4, 7)
      expect(ip.company).to eq "vfc"
      expect(ip.currency).to eq "USD"
      expect(ip.vendor_reference).to eq "REFERENCE"
      expect(ip.shipment_customer_number).to eq "STALBO"

      il = ip.intacct_payable_lines.first
      expect(il.charge_code).to eq "0007"
      expect(il.amount).to eq BigDecimal("85")
      expect(il.gl_account).to eq "1234"
      expect(il.charge_description).to eq "CUSTOMS ENTRY - REFERENCE"
      expect(il.location).to eq "10"
      expect(il.line_of_business).to eq "Brokerage"
      expect(il.customer_number).to eq "TALBO"
      expect(il.broker_file).to eq "2529468"

      expect(inbound_file).to have_identifier(:invoice_number, "2529468A")
      expect(inbound_file).to have_identifier(:broker_reference, "2529468")
    end

    it "uses customer and vendor cross references" do
      DataCrossReference.create! key: "Alliance*~*TALBO", value: "CUSTALT", cross_reference_type: "in_cust"
      DataCrossReference.create! key: "Alliance*~*VENDOR", value: "VENDALT", cross_reference_type: "in_vend"

      subject.parse document
      export = IntacctAllianceExport.first
      expect(export.customer_number).to eq "CUSTALT"

      r = export.intacct_receivables.first
      expect(r.customer_number).to eq "CUSTALT"

      l = r.intacct_receivable_lines.first
      expect(l.vendor_number).to eq "VENDALT"

      ip = export.intacct_payables.first
      expect(ip.vendor_number).to eq "VENDALT"

      l = ip.intacct_payable_lines.first
      expect(l.customer_number).to eq "CUSTALT"
    end

    it "updates existing payables and receivables that have not been sent to Intacct" do
      p = existing_payable
      r = existing_receivable
      subject.parse document

      expect(inbound_file).not_to have_warning_message("Receivable 2529468A has already been sent to Intacct.")
      expect(inbound_file).not_to have_warning_message("Payable 2529468A to Vendor VENDOR has already been sent to Intacct.")

      # I don't think we need to check every field, on the receivable / payable here...just make sure some data was loaded.
      r.reload
      p.reload

      expect(r.invoice_date).to eq Date.new(2020, 4, 7)
      expect(r.intacct_receivable_lines.length).to eq 1

      expect(p.bill_date).to eq Date.new(2020, 4, 7)
      expect(p.intacct_payable_lines.length).to eq 1

      expect(p.intacct_alliance_export.data_received_date).not_to be_nil
    end

    it "does not modify payables or receivables that have already been sent to Intacct" do
      existing_payable.update! intacct_upload_date: Time.zone.now
      existing_receivable.update! intacct_upload_date: Time.zone.now

      subject.parse document

      expect(inbound_file).to have_warning_message("Receivable 2529468A has already been sent to Intacct.")
      expect(inbound_file).to have_warning_message("Payable 2529468A to Vendor VENDOR has already been sent to Intacct.")

      existing_payable.reload
      existing_receivable.reload

      expect(existing_payable.intacct_payable_lines.length).to eq 0
      expect(existing_receivable.intacct_receivable_lines.length).to eq 0
    end

    it "removes existing receivables that are not referenced in the new file, that have NOT been sent to Intacct already" do
      existing_receivable.update! invoice_number: "2529468"
      existing_payable.update! bill_number: "2529468"

      subject.parse document

      expect(existing_receivable).not_to exist_in_db
      expect(existing_payable).not_to exist_in_db
      existing_export.reload
      expect(existing_export.intacct_payables.length).to eq 1
      expect(existing_export.intacct_receivables.length).to eq 1
    end

    it "does not remove existing receivables that are not referenced in the new file, if they have been sent to Intacct" do
      existing_receivable.update! invoice_number: "2529468", intacct_upload_date: Time.zone.now
      existing_payable.update! bill_number: "2529468", intacct_upload_date: Time.zone.now

      subject.parse document

      expect(existing_receivable).to exist_in_db
      expect(existing_payable).to exist_in_db
    end

    it "skips suppressed invoices" do
      xml_data.gsub! "<invoiceSuppressed/>", "<invoiceSuppressed>Y</invoiceSuppressed>"
      subject.parse document
      expect(IntacctAllianceExport.count).to eq 0
      expect(inbound_file).to have_warning_message("Invoice has been marked as suppressed.")
    end

    it "skips invoices that are not yet prepared" do
      xml_data.gsub! "<invoicePrepared>Y</invoicePrepared>", "<invoicePrepared>N</invoicePrepared>"
      subject.parse document
      expect(IntacctAllianceExport.count).to eq 0
      expect(inbound_file).to have_warning_message("Invoice has not been marked as prepared.")
    end

    it "skips receivable lines that are not marked as printable" do
      xml_data.gsub! "<printY>Y</printY>", "<printY>N</printY>"
      subject.parse document

      export = IntacctAllianceExport.first
      expect(export.intacct_receivables.length).to eq 0
      expect(export.intacct_payables.length).to eq 1
    end

    it "handles billing reversals" do
      xml_data.gsub! "<chargeAmtAmt>85.00</chargeAmtAmt>", "<chargeAmtAmt>-85.00</chargeAmtAmt>"

      subject.parse document

      export = IntacctAllianceExport.first
      expect(export.ar_total).to eq BigDecimal("-85")
      expect(export.ap_total).to eq BigDecimal("-85")

      expect(export.intacct_receivables.length).to eq 1
      ir = export.intacct_receivables.first
      expect(ir.receivable_type).to eq "VFI Credit Note"

      expect(ir.intacct_errors).to be_nil
      expect(ir.intacct_upload_date).to be_nil

      expect(ir.intacct_receivable_lines.length).to eq 1
      rl = ir.intacct_receivable_lines.first

      expect(rl.amount).to eq BigDecimal("85")

      expect(export.intacct_payables.length).to eq 1

      ip = export.intacct_payables.first
      il = ip.intacct_payable_lines.first
      expect(il.amount).to eq BigDecimal("-85")
    end

    context "with no Duty Paid Direct line" do
      let (:xml_data) { IO.read 'spec/fixtures/files/cmus_billing_file_without_duty_direct.xml'}
      let! (:gl_account_duty_xref) { DataCrossReference.create! key: "0001", value: "9999", cross_reference_type: "al_gl_code" }

      it "does not skip duty line if Duty Paid Direct line is not present" do
        subject.parse document

        export = IntacctAllianceExport.first
        expect(export.ap_total).to eq BigDecimal("10839.21")
        expect(export.ar_total).to eq BigDecimal("10924.21")

        expect(export.intacct_receivables.length).to eq 1
        expect(export.intacct_payables.length).to eq 1
        ip = export.intacct_payables.first

        expect(ip.bill_number).to eq "2529468A"
        expect(ip.vendor_number).to eq "VU160"
        expect(ip.payable_type).to eq "bill"
        expect(ip.bill_date).to eq Date.new(2020, 4, 7)
        expect(ip.company).to eq "vfc"
        expect(ip.currency).to eq "USD"
        expect(ip.vendor_reference).to eq "316-02529468-6"

        il = ip.intacct_payable_lines.first
        expect(il.charge_code).to eq "0001"
        expect(il.amount).to eq BigDecimal("10839.21")
        expect(il.gl_account).to eq "9999"
        expect(il.charge_description).to eq "DUTY - 316-02529468-6"
        expect(il.location).to eq "10"
        expect(il.line_of_business).to eq "Brokerage"
        expect(il.customer_number).to eq "TALBO"
        expect(il.broker_file).to eq "2529468"
      end
    end
  end
end
describe OpenChain::CustomHandler::Intacct::IntacctCargowiseFreightBillingFileParser do

  describe "parse" do
    let (:document) do
      xml = Nokogiri::XML(xml_data)
      xml.remove_namespaces!
      xml
    end

    let! (:inbound_file) do
      f = InboundFile.new
      allow(subject).to receive(:inbound_file).and_return f
      f
    end

    let! (:gl_account_xref) { DataCrossReference.create! key: "0401", value: "1234", cross_reference_type: "al_gl_code" }

    let! (:master_setup) do
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("Cargowise Freight Billing").and_return true

      ms
    end

    context "with AP invoice" do
      let (:xml_data) { IO.read 'spec/fixtures/files/cargowise_freight_billing_ap_file.xml' }
      let (:existing_export) { IntacctAllianceExport.create! file_number: "00001001/A", export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE }
      let (:existing_payable) { existing_export.intacct_payables.create! bill_number: "00001001/A", vendor_number: "VANLOGEWR" }

      it "parses billing data into export and payable" do
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
        expect(export.file_number).to eq "00001001/A"
        expect(export.suffix).to be_blank
        expect(export.division).to eq "12"
        expect(export.customer_number).to eq "VANLOGEWR"
        expect(export.shipment_customer_number).to eq "SHOFORBCT"
        expect(export.invoice_date).to eq Date.new(2020, 9, 11)
        expect(export.broker_reference).to eq "59556932081"
        expect(export.shipment_number).to eq "S00001062"
        expect(export.ar_total).to eq BigDecimal("0")
        expect(export.ap_total).to eq BigDecimal("20")
        expect(export.data_requested_date).to eq now
        expect(export.data_received_date).to eq now

        expect(export.intacct_receivables.length).to eq 0
        expect(export.intacct_payables.length).to eq 1

        ip = export.intacct_payables.first
        expect(ip.bill_number).to eq "00001001/A"
        expect(ip.vendor_number).to eq "VANLOGEWR"
        expect(ip.payable_type).to eq "bill"
        expect(ip.bill_date).to eq Date.new(2020, 9, 11)
        expect(ip.company).to eq "lmd"
        expect(ip.currency).to eq "USD"
        expect(ip.vendor_reference).to eq "INV564567"
        expect(ip.shipment_customer_number).to eq "SHOFORBCT"

        il = ip.intacct_payable_lines.first
        expect(il.charge_code).to eq "0401"
        expect(il.amount).to eq BigDecimal("20")
        expect(il.gl_account).to eq "1234"
        expect(il.charge_description).to eq "E ADJUSTED FREIGHT PROFIT"
        expect(il.location).to eq "12"
        expect(il.line_of_business).to eq "Freight"
        expect(il.customer_number).to eq "SHOFORBCT"
        expect(il.broker_file).to eq "59556932081"
        expect(il.freight_file).to eq "S00001062"

        expect(inbound_file).to have_identifier(:invoice_number, "00001001/A")
        expect(inbound_file).to have_identifier(:broker_reference, "S00001062")
      end

      it "handles customer and vendor translations" do
        DataCrossReference.create! key: "Alliance*~*VANLOGEWR", value: "CUSTALT", cross_reference_type: "in_cust"
        DataCrossReference.create! key: "Alliance*~*SHOFORBCT", value: "SHOESALT", cross_reference_type: "in_cust"
        DataCrossReference.create! key: "Alliance*~*VANLOGEWR", value: "VENDALT", cross_reference_type: "in_vend"

        subject.parse document

        export = IntacctAllianceExport.first

        expect(export.customer_number).to eq "CUSTALT"

        ip = export.intacct_payables.first
        expect(ip.vendor_number).to eq "VENDALT"

        il = ip.intacct_payable_lines.first
        expect(il.customer_number).to eq "SHOESALT"
      end

      it "updates existing payables and receivables that have not been sent to Intacct" do
        p = existing_payable
        subject.parse document

        expect(inbound_file).not_to have_warning_message("Payable 00001001/A to Vendor VANLOGEWR has already been sent to Intacct.")

        # I don't think we need to check every field, on the payable here...just make sure some data was loaded.
        p.reload

        expect(p.bill_date).to eq Date.new(2020, 9, 11)
        expect(p.intacct_payable_lines.length).to eq 1

        expect(p.intacct_alliance_export.data_received_date).not_to be_nil
      end

      it "does not modify payables that have already been sent to Intacct" do
        existing_payable.update! intacct_upload_date: Time.zone.now

        subject.parse document

        expect(inbound_file).to have_reject_message("Payable 00001001/A to Vendor VANLOGEWR has already been sent to Intacct.")

        existing_payable.reload

        expect(existing_payable.intacct_payable_lines.length).to eq 0
      end

      it "removes existing payables that are not referenced in the new file, that have NOT been sent to Intacct already" do
        existing_payable.update! bill_number: "2529468"

        subject.parse document

        expect(existing_payable).not_to exist_in_db
        existing_export.reload
        expect(existing_export.intacct_payables.length).to eq 1
      end

      it "does not remove existing payables that are not referenced in the new file, if they have been sent to Intacct" do
        # This is really an outdated concept for the Cargowise files, but I'm still testing for it because there
        existing_payable.update! bill_number: "2529468", intacct_upload_date: Time.zone.now

        subject.parse document

        expect(existing_payable).to exist_in_db
      end

      {"FEA" => "14", "FES" => "13", "FIS" => "11"}.each_pair do |department_code, location|
        it "handles alternate division #{department_code}" do
          xml_data.gsub! "<Code>FIA</Code>", "<Code>#{department_code}</Code>"

          subject.parse document

          export = IntacctAllianceExport.first
          expect(export.division).to eq location

          ip = export.intacct_payables.first

          if ["FEA", "FES"].include? department_code
            expect(ip.company).to eq "vfc"
          else
            expect(ip.company).to eq "lmd"
          end

          il = ip.intacct_payable_lines.first
          expect(il.location).to eq location
        end
      end

      it "handles billing reversals" do
        xml_data.gsub! "<OSTotalAmount>-20.0000</OSTotalAmount>", "<OSTotalAmount>20.0000</OSTotalAmount>"

        subject.parse document

        export = IntacctAllianceExport.first
        expect(export.ap_total).to eq BigDecimal("-20")

        expect(export.intacct_payables.length).to eq 1

        ip = export.intacct_payables.first
        il = ip.intacct_payable_lines.first
        expect(il.amount).to eq BigDecimal("-20")
      end
    end

    context "with AR invoice" do
      let (:xml_data) { IO.read 'spec/fixtures/files/cargowise_freight_billing_ar_file.xml' }
      let (:existing_export) { IntacctAllianceExport.create! file_number: "S00001072", export_type: IntacctAllianceExport::EXPORT_TYPE_INVOICE }
      let (:existing_receivable) { existing_export.intacct_receivables.create! invoice_number: "S00001072" }

      it "parses billing data into export and receivable" do
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
        expect(export.file_number).to eq "S00001072"
        expect(export.suffix).to be_blank
        expect(export.division).to eq "11"
        expect(export.customer_number).to eq "VANLOGEWR"
        expect(export.shipment_customer_number).to eq "SHOFORBCT"
        expect(export.invoice_date).to eq Date.new(2020, 10, 5)
        expect(export.broker_reference).to eq "59556932081"
        expect(export.shipment_number).to eq "S00001072"
        expect(export.ar_total).to eq BigDecimal("5000")
        expect(export.ap_total).to eq BigDecimal("0")
        expect(export.data_requested_date).to eq now
        expect(export.data_received_date).to eq now

        expect(export.intacct_receivables.length).to eq 1
        expect(export.intacct_payables.length).to eq 0

        ir = export.intacct_receivables.first
        expect(ir.currency).to eq "USD"
        expect(ir.invoice_number).to eq "S00001072"
        expect(ir.company).to eq "lmd"
        expect(ir.invoice_date).to eq Date.new(2020, 10, 5)
        expect(ir.customer_number).to eq "VANLOGEWR"
        expect(ir.shipment_customer_number).to eq "SHOFORBCT"
        expect(ir.receivable_type).to eq "LMD Sales Invoice"
        expect(ir.intacct_errors).to be_nil
        expect(ir.intacct_upload_date).to be_nil

        expect(ir.intacct_receivable_lines.length).to eq 1
        rl = ir.intacct_receivable_lines.first

        expect(rl.amount).to eq BigDecimal("5000")
        expect(rl.location).to eq "11"
        expect(rl.charge_code).to eq "0514"
        expect(rl.charge_description).to eq "E TERMINAL HANDLING FEE"
        expect(rl.broker_file).to eq "59556932081"
        expect(rl.freight_file).to eq "S00001072"
        expect(rl.line_of_business).to eq "Freight"
        expect(rl.vendor_number).to be_blank
        expect(rl.vendor_reference).to be_blank

        expect(inbound_file).to have_identifier(:invoice_number, "S00001072")
        expect(inbound_file).to have_identifier(:broker_reference, "S00001072")
      end

      it "handles customer and translations" do
        DataCrossReference.create! key: "Alliance*~*VANLOGEWR", value: "CUSTALT", cross_reference_type: "in_cust"

        subject.parse document

        export = IntacctAllianceExport.first

        expect(export.customer_number).to eq "CUSTALT"
        ir = export.intacct_receivables.first
        expect(ir.customer_number).to eq "CUSTALT"
      end

      it "updates existing receivables that have not been sent to Intacct" do
        r = existing_receivable
        subject.parse document

        expect(inbound_file).not_to have_reject_message("Receivable S00001072 has already been sent to Intacct.")

        # I don't think we need to check every field, on the receivable here...just make sure some data was loaded.
        r.reload

        expect(r.invoice_date).to eq Date.new(2020, 10, 5)
        expect(r.intacct_receivable_lines.length).to eq 1

        expect(r.intacct_alliance_export.data_received_date).not_to be_nil
      end

      it "does not modify receivables that have already been sent to Intacct" do
        existing_receivable.update! intacct_upload_date: Time.zone.now

        subject.parse document

        expect(inbound_file).to have_reject_message("Receivable S00001072 has already been sent to Intacct.")

        existing_receivable.reload

        expect(existing_receivable.intacct_receivable_lines.length).to eq 0
      end

      it "removes existing receivables that are not referenced in the new file, that have NOT been sent to Intacct already" do
        existing_receivable.update! invoice_number: "2529468"
        subject.parse document

        expect(existing_receivable).not_to exist_in_db
        existing_export.reload
        expect(existing_export.intacct_receivables.length).to eq 1
      end

      it "does not remove existing receivables that are not referenced in the new file, if they have been sent to Intacct" do
        existing_receivable.update! invoice_number: "2529468", intacct_upload_date: Time.zone.now

        subject.parse document

        expect(existing_receivable).to exist_in_db
      end

      {"FEA" => "14", "FES" => "13", "FIA" => "12"}.each_pair do |department_code, location|
        it "handles alternate division #{department_code}" do
          xml_data.gsub! "<Code>FIS</Code>", "<Code>#{department_code}</Code>"

          subject.parse document

          export = IntacctAllianceExport.first
          expect(export.division).to eq location

          ir = export.intacct_receivables.first

          if ["FEA", "FES"].include? department_code
            expect(ir.company).to eq "vfc"
          else
            expect(ir.company).to eq "lmd"
          end

          rl = ir.intacct_receivable_lines.first
          expect(rl.location).to eq location
        end
      end

      it "handles receivable billing reversals" do
        xml_data.gsub! "<OSTotalAmount>5000.0000</OSTotalAmount>", "<OSTotalAmount>-5000.0000</OSTotalAmount>"

        subject.parse document

        export = IntacctAllianceExport.first
        expect(export.ar_total).to eq BigDecimal("-5000")

        expect(export.intacct_receivables.length).to eq 1
        ir = export.intacct_receivables.first
        expect(ir.receivable_type).to eq "LMD Credit Note"

        expect(ir.intacct_errors).to be_nil
        expect(ir.intacct_upload_date).to be_nil

        expect(ir.intacct_receivable_lines.length).to eq 1
        rl = ir.intacct_receivable_lines.first

        expect(rl.amount).to eq BigDecimal("5000")
      end
    end

    context "without custom feature enabled" do
      let (:xml_data) { IO.read 'spec/fixtures/files/cargowise_freight_billing_ar_file.xml' }

      it "rejects the file" do
        expect(master_setup).to receive(:custom_feature?).with("Cargowise Freight Billing").and_return false
        subject.parse document

        expect(inbound_file).to have_identifier(:invoice_number, "S00001072")
        expect(inbound_file).to have_identifier(:broker_reference, "S00001072")
        expect(inbound_file).to have_reject_message("Cargowise Freight Billing has not been enabled.")
      end
    end

  end
end
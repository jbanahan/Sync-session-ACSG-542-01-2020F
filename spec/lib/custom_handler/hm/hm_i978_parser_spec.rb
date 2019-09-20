describe OpenChain::CustomHandler::Hm::HmI978Parser do

  let(:xml_data) { IO.read 'spec/fixtures/files/hm_i978.xml' }
  let!(:ms) { stub_master_setup }
  let! (:inbound_file) {
    f = InboundFile.new
    allow(subject).to receive(:inbound_file).and_return f
    f
  }
  let (:product_importer) { Factory(:importer, system_code: "HENNE") }
  let (:cn) { Factory(:country, iso_code: "CN") }
  let (:ca) { Factory(:country, iso_code: "CA") }
  let (:us) { Factory(:country, iso_code: "US") }
  let (:product) {
    # Delivery Item # 1
    p = Factory(:product, unique_identifier: "HENNE-0615141", importer_id: product_importer.id)
    p.update_hts_for_country country, "6115950000"
    p
  }
  let (:product_2) {
    # Delivery Item # 2 / 3
    p = Factory(:product, unique_identifier: "HENNE-0742769", importer_id: product_importer.id)
    p.update_hts_for_country country, "6115951111"
    p
  }

  describe "process_shipment_xml" do
    let (:xml) { REXML::XPath.first(REXML::Document.new(xml_data), "/ns0:CustomsTransactionalDataTransaction/Payload/CustomsTransactionalData/BILLING_SHIPMENT")}
    let (:user) { Factory(:user) }

    before :each do 
      product_importer
      cn
      ca
      us
      product
      product_2
    end

    context "with canada import" do
      let! (:importer) { with_fenix_id(Factory(:importer), "887634400RM0001")}
      let! (:country) { ca }
      let! (:data_cross_reference) { DataCrossReference.create! cross_reference_type: "hm_pars", key: "PARS"}
      let! (:ca_email_lists) { 
        MailingList.create! user_id: User.integration.id, company_id: product_importer.id, system_code: "h_m_pars_coversheet_1", name: "PARS Coversheet", email_addresses: "parscoversheet@company.com"
        MailingList.create! user_id: User.integration.id, company_id: product_importer.id, system_code: "canada_h_m_i978_files_1", name: "FILES", email_addresses: "cafiles@company.com"
        MailingList.create! user_id: User.integration.id, company_id: product_importer.id, system_code: "PARSNumbersNeeded", name: "PARS Needed", email_addresses: "morepars@company.com"
      }

      before :each do 
        allow(ms).to receive(:custom_feature?).with("H&M i978 CA Import Live").and_return true
      end

      it "creates canadian invoice" do
        expect(subject).to receive(:generate_and_send_pars_pdf)
        expect(subject).to receive(:check_unused_pars_count)
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::FenixNdInvoice810Generator).to receive(:generate_and_send_810) do |instance, invoice, sync_record|
          expect(invoice.invoice_number).to eq "1234567891011"
          expect(sync_record.trading_partner).to eq "CA i978"
          expect(sync_record.syncable).to eq invoice
        end

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(invoices.length).to eq 1

        i = invoices[0]
        i.reload

        expect(i.importer).to eq importer
        expect(i.invoice_number).to eq "1234567891011"
        expect(i.customer_reference_number_2).to eq "PARS"
        expect(i.last_file_path).to eq "filename"
        expect(i.last_file_bucket).to eq "bucket"
        expect(i.last_exported_from_source).to eq Time.zone.parse("20181004223500")

        expect(i.invoice_date).to eq Date.new(2018, 10, 4)
        expect(i.terms_of_sale).to eq "FCA"
        expect(i.customer_reference_number).to eq "A019000144"
        expect(i.currency).to eq "NOK"
        expect(i.country_import).to eq ca
        expect(i.gross_weight).to eq BigDecimal("0.9")
        expect(i.gross_weight_uom).to eq "KG"
        expect(i.net_weight).to eq BigDecimal("0.75")
        expect(i.invoice_total_foreign).to eq BigDecimal("1795.04")

        expect(i.invoice_lines.length).to eq 3

        l = i.invoice_lines.first
        expect(l.po_number).to eq "E000003487"
        expect(l.po_line_number).to eq "000010"
        expect(l.part_number).to eq "0615141"
        expect(l.sku).to eq "000615141001188004"
        expect(l.part_description).to eq "TROUSERS GREEN,44 - 100% BCI COTTON"
        expect(l.quantity).to eq BigDecimal("2")
        expect(l.quantity_uom).to eq "PC"
        expect(l.unit_price).to eq BigDecimal("437.76")
        expect(l.country_origin).to eq cn
        expect(l.net_weight).to eq BigDecimal("0.25")
        expect(l.net_weight_uom).to eq "KG"
        expect(l.gross_weight).to eq BigDecimal("0.3")
        expect(l.gross_weight_uom).to eq "KG"
        expect(l.master_bill_of_lading).to eq "12345668866"
        expect(l.customer_reference_number).to eq "123456"
        expect(l.carrier_name).to eq "HMTESTDATA"
        expect(l.value_foreign).to eq BigDecimal("875.52")
        expect(l.customer_reference_number_2).to eq "8454548"
        expect(l.secondary_po_number).to eq "217711434XXX"
        expect(l.secondary_po_line_number).to eq "000020"
        expect(l.hts_number).to eq "6115950000"

        expect(i.sync_records.length).to eq 1
        sr = i.sync_records.first
        expect(sr.trading_partner).to eq "CA i978"
        expect(sr.sent_at).not_to be_nil

        expect(ActionMailer::Base.deliveries.length).to eq 1
        m = ActionMailer::Base.deliveries.first
        expect(m.to).to eq ["cafiles@company.com"]
        expect(m.subject).to eq "H&M Commercial Invoice 1234567891011"
        expect(m.attachments.length).to eq 1
        expect(m.attachments["Invoice 1234567891011.xlsx"]).not_to be_nil

        expect(inbound_file).to have_identifier(:invoice_number, "1234567891011", i)
        expect(inbound_file).to have_identifier(:pars_number, "PARS")

        data_cross_reference.reload
        expect(data_cross_reference.value).not_to be_nil
      end

      it "falls back to tracking HybrisOrderNumber if CustomerOrderNumber is missing" do
        xml_data.gsub!("<CustomerOrderNumber>217711434XXX</CustomerOrderNumber>", "").gsub!("<CustomerOrderItemNumber>000020</CustomerOrderItemNumber>", "")

        expect(subject).to receive(:generate_and_send_pars_pdf)
        expect(subject).to receive(:check_unused_pars_count)
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::FenixNdInvoice810Generator).to receive(:generate_and_send_810) do |instance, invoice, sync_record|
          expect(invoice.invoice_number).to eq "1234567891011"
          expect(sync_record.trading_partner).to eq "CA i978"
          expect(sync_record.syncable).to eq invoice
        end

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(invoices.length).to eq 1

        i = invoices[0]
        i.reload
        expect(i.invoice_lines.length).to eq 3

        l = i.invoice_lines.first
        expect(l.secondary_po_number).to eq "217711434336"
        expect(l.secondary_po_line_number).to eq "000010"
      end

      it "splits shipments if too many lines are found, handling case where last item is a new shipment" do
        # This test makes sure that we handle cases where the last line is on a new shipment
        expect(subject).to receive(:max_fenix_invoice_length).and_return 1

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(invoices.length).to eq 3
        expect(invoices.first.invoice_number).to eq "1234567891011-01"
        expect(invoices.second.invoice_number).to eq "1234567891011-02"
        expect(invoices.third.invoice_number).to eq "1234567891011-03"
      end

      it "splits shipments if too many lines are found, handles case where last PO needs to go on new shipment" do
        xml_data.gsub!("<SalesOrderNumber>E000003489</SalesOrderNumber>", "<SalesOrderNumber>E000003490</SalesOrderNumber>")
        expect(subject).to receive(:max_fenix_invoice_length).and_return 2

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(invoices.length).to eq 2

        expect(invoices.first.invoice_lines.length).to eq 1
        expect(invoices.second.invoice_lines.length).to eq 2
      end

      it "splits shipments if too many lines are found, handles case where last line is new file" do
        xml_data.gsub!("<SalesOrderNumber>E000003490</SalesOrderNumber>", "<SalesOrderNumber>E000003487</SalesOrderNumber>")
        expect(subject).to receive(:max_fenix_invoice_length).and_return 2

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(invoices.length).to eq 2

        expect(invoices.first.invoice_lines.length).to eq 2
        expect(invoices.second.invoice_lines.length).to eq 1
      end

      it "re-uses same pars number on updates, and does not resend data if sync record exists" do
        expect(subject).to receive(:generate_and_send_pars_pdf)
        expect(subject).to receive(:check_unused_pars_count)
        expect(subject).not_to receive(:generate_invoice_addendum)
        expect(subject).not_to receive(:generate_missing_parts_spreadsheet)

        i = Invoice.create! importer_id: importer.id, invoice_number: "1234567891011", customer_reference_number_2: "EXISTING"
        i.sync_records.create! trading_partner: "CA i978", sent_at: Time.zone.now

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(invoices.length).to eq 1

        i = invoices[0]
        expect(i.customer_reference_number_2).to eq "EXISTING"
        expect(ActionMailer::Base.deliveries.length).to eq 0
      end

      it "adds part to exception report if missing" do
        product_2.destroy
        expect(subject).to receive(:generate_and_send_pars_pdf)
        expect(subject).to receive(:check_unused_pars_count)

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(invoices.length).to eq 1

        expect(ActionMailer::Base.deliveries.length).to eq 1
        m = ActionMailer::Base.deliveries.first
        expect(m.attachments.length).to eq 2
        expect(m.attachments["Invoice 1234567891011.xlsx"]).not_to be_nil
        expect(m.attachments["1234567891011 Exceptions.xlsx"]).not_to be_nil
      end

      it "adds part to exception report if hts is missing" do
        product_2.classifications.destroy_all

        expect(subject).to receive(:generate_and_send_pars_pdf)
        expect(subject).to receive(:check_unused_pars_count)

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(invoices.length).to eq 1

        expect(ActionMailer::Base.deliveries.length).to eq 1
        m = ActionMailer::Base.deliveries.first
        expect(m.attachments.length).to eq 2
        expect(m.attachments["Invoice 1234567891011.xlsx"]).not_to be_nil
        expect(m.attachments["1234567891011 Exceptions.xlsx"]).not_to be_nil
      end

      it "does not generate files or send out emails if it is not the primary parser" do
        allow(ms).to receive(:custom_feature?).with("H&M i978 CA Import Live").and_return false
        expect(subject).not_to receive(:generate_and_send_pars_pdf)
        expect(subject).not_to receive(:check_unused_pars_count)
        expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::FenixNdInvoice810Generator).not_to receive(:generate_and_send_810)
        # Make sure the exception report is also not generated by setting up a product that will be an exception
        product_2.classifications.destroy_all

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(inbound_file).to have_info_message("i978 process is not fully enabled.  No files will be emitted from this parser.")
        expect(invoices.length).to eq 1
        i = invoices.first
        expect(i.sync_records.length).to eq 0
        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
    end

    context "with us import" do
      let! (:importer) { product_importer }
      let! (:country) { us }
      let! (:us_email_lists) { 
        MailingList.create! user_id: User.integration.id, company_id: importer.id, system_code: "us_h_m_i978_exception_files_1", name: "Exception", email_addresses: "exception@company.com"
        MailingList.create! user_id: User.integration.id, company_id: importer.id, system_code: "us_h_m_i978_files_1", name: "FILES", email_addresses: "usfiles@company.com"
      }
      let! (:entry) {
        e = Factory(:entry, source_system: "Alliance", importer: importer, release_date: Time.zone.now, export_country_codes: "CN")
        inv = Factory(:commercial_invoice, entry: e, invoice_number: "123456")
        inv_line = Factory(:commercial_invoice_line, commercial_invoice: inv, country_origin_code: "CN", part_number: "0615141", mid: "MID1")
        inv_line_2 = Factory(:commercial_invoice_line, commercial_invoice: inv, country_origin_code: "CN", part_number: "0742769", mid: "MID2")

        e.reload
      }

      before :each do
        allow(ms).to receive(:custom_feature?).with("H&M i978 US Import Live").and_return true
        xml_data.gsub!("<SendingSite>W068</SendingSite>", "<SendingSite>W184</SendingSite>").gsub!("<HMOrderNumber>567890</HMOrderNumber>", "<HMOrderNumber>123456</HMOrderNumber>")
      end

      it "creates us invoice" do
        captured_data = []
        generator = instance_double(OpenChain::CustomHandler::Vandegrift::KewillInvoiceGenerator)
        allow(subject).to receive(:us_generator).and_return generator
        expect(generator).to receive(:generate_and_send_invoice).exactly(2).times do |invoice, sync_record|
          captured_data << {invoice: invoice, sync_record: sync_record}
        end

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(invoices.length).to eq 2
        expect(captured_data[0][:invoice].invoice_number).to eq("F000001850")
        expect(captured_data[1][:invoice].invoice_number).to eq("F000002240")

        i = invoices[0]
        i.reload

        expect(i.importer).to eq importer
        expect(i.invoice_number).to eq "F000001850"
        expect(i.customer_reference_number_2).to be_blank
        expect(i.last_file_path).to eq "filename"
        expect(i.last_file_bucket).to eq "bucket"
        expect(i.last_exported_from_source).to eq Time.zone.parse("20181004223500")

        expect(i.invoice_date).to eq Date.new(2018, 10, 4)
        expect(i.terms_of_sale).to eq "FCA"
        expect(i.customer_reference_number).to eq "A019000144"
        expect(i.currency).to eq "NOK"
        expect(i.country_import).to eq us
        expect(i.gross_weight).to eq BigDecimal("0.3")
        expect(i.gross_weight_uom).to eq "KG"
        expect(i.net_weight).to eq BigDecimal("0.25")
        expect(i.invoice_total_foreign).to eq BigDecimal("875.52")

        expect(i.invoice_lines.length).to eq 1

        l = i.invoice_lines.first
        expect(l.po_number).to eq "E000003487"
        expect(l.po_line_number).to eq "000010"
        expect(l.part_number).to eq "0615141"
        expect(l.sku).to eq "000615141001188004"
        expect(l.part_description).to eq "TROUSERS GREEN,44 - 100% BCI COTTON"
        expect(l.quantity).to eq BigDecimal("2")
        expect(l.quantity_uom).to eq "PC"
        expect(l.unit_price).to eq BigDecimal("437.76")
        expect(l.country_origin).to eq cn
        expect(l.net_weight).to eq BigDecimal("0.25")
        expect(l.net_weight_uom).to eq "KG"
        expect(l.gross_weight).to eq BigDecimal("0.3")
        expect(l.gross_weight_uom).to eq "KG"
        expect(l.master_bill_of_lading).to eq "12345668866"
        expect(l.customer_reference_number).to eq "123456"
        expect(l.carrier_name).to eq "HMTESTDATA"
        expect(l.value_foreign).to eq BigDecimal("875.52")
        expect(l.customer_reference_number_2).to eq "8454548"
        expect(l.secondary_po_number).to eq "217711434XXX"
        expect(l.secondary_po_line_number).to eq "000020"
        expect(l.hts_number).to eq "6115950000"
        expect(l.mid).to eq "MID1"

        expect(i.sync_records.length).to eq 1
        sr = i.sync_records.first
        expect(sr.trading_partner).to eq "US i978"
        expect(sr.sent_at).not_to be_nil

        i = invoices[1]
        expect(i.invoice_number).to eq "F000002240"
        expect(i.gross_weight).to eq BigDecimal("0.6")
        expect(i.gross_weight_uom).to eq "KG"
        expect(i.net_weight).to eq BigDecimal("0.50")
        expect(i.invoice_total_foreign).to eq BigDecimal("919.52")

        expect(i.invoice_lines.length).to eq 2

        # There's nothing that we need to really deal with on this second invoice that isn't already checked by the
        # expectations above for the first invoice lines

        expect(ActionMailer::Base.deliveries.length).to eq 2
        m = ActionMailer::Base.deliveries.first
        expect(m.to).to eq ["usfiles@company.com"]
        expect(m.subject).to eq "[VFI Track] H&M Returns Shipment # F000001850"
        expect(m.attachments.length).to eq 2
        expect(m.attachments["Invoice Addendum F000001850.xlsx"]).not_to be_nil
        expect(m.attachments["Invoice F000001850.pdf"]).not_to be_nil

        m = ActionMailer::Base.deliveries.second
        expect(m.subject).to eq "[VFI Track] H&M Returns Shipment # F000002240"

        expect(inbound_file).to have_identifier(:invoice_number, "F000001850", invoices[0])
        expect(inbound_file).to have_identifier(:invoice_number, "F000002240", invoices[1])
      end

      it "falls back to tracking HybrisOrderNumber if CustomerOrderNumber is missing" do
        xml_data.gsub!("<CustomerOrderNumber>217711434XXX</CustomerOrderNumber>", "").gsub!("<CustomerOrderItemNumber>000020</CustomerOrderItemNumber>", "")

        captured_data = []
        generator = instance_double(OpenChain::CustomHandler::Vandegrift::KewillInvoiceGenerator)
        allow(subject).to receive(:us_generator).and_return generator
        expect(generator).to receive(:generate_and_send_invoice).exactly(2).times do |invoice, sync_record|
          captured_data << {invoice: invoice, sync_record: sync_record}
        end

        invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
        expect(invoices.length).to eq 2
        expect(captured_data[0][:invoice].invoice_number).to eq("F000001850")

        i = invoices[0]
        i.reload
        expect(i.invoice_lines.length).to eq 1
        l = i.invoice_lines.first
        expect(l.secondary_po_number).to eq "217711434336"
        expect(l.secondary_po_line_number).to eq "000010"
      end

      context "with single invoice" do

        before :each do 
          xml_data.gsub!("<DeliveryNumber>F000001850</DeliveryNumber>", "<DeliveryNumber>F000002240</DeliveryNumber>").gsub!("<SSCCNumber>8454548</SSCCNumber>", "<SSCCNumber>84547448</SSCCNumber>")
        end

        it "sends exception report if mid is missing" do
          entry.commercial_invoices.first.commercial_invoice_lines.first.destroy
          subject.process_shipment_xml xml, user, "bucket", "filename"

          expect(ActionMailer::Base.deliveries.length).to eq 2
          m = ActionMailer::Base.deliveries.first
          expect(m.to).to eq ["usfiles@company.com"]

          m = ActionMailer::Base.deliveries.second
          expect(m.to).to eq ["exception@company.com"]
          expect(m.subject).to eq "[VFI Track] H&M Commercial Invoice F000002240 Exceptions"
          expect(m.attachments.length).to eq 1
          expect(m.attachments["F000002240 Exceptions.xlsx"]).not_to be_nil
        end

        it "sends exception report if hts is missing" do
          product.classifications.destroy_all
          subject.process_shipment_xml xml, user, "bucket", "filename"

          m = ActionMailer::Base.deliveries.second
          expect(m.attachments["F000002240 Exceptions.xlsx"]).not_to be_nil
        end

        it "sends exception if product is missing" do
          product.destroy
          subject.process_shipment_xml xml, user, "bucket", "filename"

          m = ActionMailer::Base.deliveries.second
          expect(m.attachments["F000002240 Exceptions.xlsx"]).not_to be_nil
        end

        it "converts Myanmaar country code to Burma for US entries" do
          burma = Factory(:country, iso_code: "BU")

          xml_data.gsub!("<COO>CN</COO>", "<COO>MM</COO>")
          invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
          i = invoices[0]

          expect(i.invoice_lines.first.country_origin).to eq burma
        end

        it "does not generate files or send out emails if it is not the primary parser" do
          allow(ms).to receive(:custom_feature?).with("H&M i978 US Import Live").and_return false
          expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillInvoiceGenerator).not_to receive(:generate_and_send_invoice)
          # Make sure the exception report is also not generated by setting up a product that will be an exception
          product_2.classifications.destroy_all

          invoices = subject.process_shipment_xml xml, user, "bucket", "filename"
          expect(inbound_file).to have_info_message("i978 process is not fully enabled.  No files will be emitted from this parser.")
          expect(invoices.length).to eq 1
          i = invoices.first
          expect(i.sync_records.length).to eq 0
          expect(ActionMailer::Base.deliveries.length).to eq 0
        end
      end
      
    end

    context "it errors" do 
      let! (:country) { ca }

      it "if InvoiceNumber is missing" do
        xml_data.gsub!("<ExternalID>1234567891011</ExternalID>", "")
        expect { subject.process_shipment_xml xml, user, "bucket", "filename" }.to raise_error(StandardError)

        expect(inbound_file).to have_reject_message "Expected to find Invoice Number in the BILLING_SHIPMENT/ExternalID element, but it was blank or missing."
      end
    end
  end

  describe "generate_missing_parts_spreadsheet" do
    let (:invoice) {
      invoice = Invoice.create! invoice_number: "INV", importer_id: importer.id
      invoice_line = invoice.invoice_lines.create! part_number: "12345", part_description: "DESC", product_id: product.id, country_origin_id: cn.id, customer_reference_number: "PO", value_foreign: BigDecimal("9.99"), mid: "MID", hts_number: "1234567890"
      invoice
    }

    let! (:entry) {
      e = Factory(:entry, source_system: "Alliance", importer: product_importer, release_date: Time.zone.now, export_country_codes: "CN", broker_reference: "REF")
      inv = Factory(:commercial_invoice, entry: e, invoice_number: "PO")      
      e.reload
    }

    before :each do 
      us
      ca
    end

    context "with ca data" do
      let (:country) { ca }
      let! (:importer) { Factory(:importer, fenix_customer_number: "887634400RM0001")}

      it "does not generate exception spreadsheet if nothing is missing" do
        expect(subject.generate_missing_parts_spreadsheet invoice).to be_nil
      end

      it "generates spreadsheet if part is missing" do
        invoice.invoice_lines.first.product = nil

        spreadsheet = subject.generate_missing_parts_spreadsheet invoice
        expect(spreadsheet).not_to be_nil
        data = xlsx_data(spreadsheet, sheet_name: "INV Exceptions")
        expect(data.length).to eq 2
        expect(data[0]).to eq ["Part Number", "H&M Order #", "H&M Country Origin", "H&M Description", "US HS Code", "CA HS Code", "Product Value", "MID", "Product Link", "US Entry Links", "Resolution"]
        expect(data[1]).to eq ["12345", "PO", "CN", "DESC", nil, nil, 9.99, "MID", nil, "REF", "No Product record exists in VFI Track.  H&M did not send an I1 file for this product."]
      end

      it "generates spreadsheet if hts is missing" do
        invoice.invoice_lines.first.hts_number = nil

        spreadsheet = subject.generate_missing_parts_spreadsheet invoice
        expect(spreadsheet).not_to be_nil
        data = xlsx_data(spreadsheet, sheet_name: "INV Exceptions")
        expect(data.length).to eq 2
        expect(data[0]).to eq ["Part Number", "H&M Order #", "H&M Country Origin", "H&M Description", "US HS Code", "CA HS Code", "Product Value", "MID", "Product Link", "US Entry Links", "Resolution"]
        expect(data[1]).to eq ["12345", "PO", "CN", "DESC", nil, "6115.95.0000", 9.99, "MID", "12345", "REF", "Use linked Product and add Canadian classification in VFI Track."]
      end
    end

    context "with us data" do
      let (:country) { us }
      let! (:importer) { product_importer }

      it "does not generate exception spreadsheet if nothing is missing" do
        expect(subject.generate_missing_parts_spreadsheet invoice).to be_nil
      end

      it "generates spreadsheet if part is missing" do
        invoice.invoice_lines.first.product = nil

        spreadsheet = subject.generate_missing_parts_spreadsheet invoice
        expect(spreadsheet).not_to be_nil
        data = xlsx_data(spreadsheet, sheet_name: "INV Exceptions")
        expect(data.length).to eq 2
        expect(data[0]).to eq ["Part Number", "H&M Order #", "H&M Country Origin", "H&M Description", "US HS Code", "CA HS Code", "Product Value", "MID", "Product Link", "US Entry Links", "Resolution"]
        expect(data[1]).to eq ["12345", "PO", "CN", "DESC", nil, nil, 9.99, "MID", nil, "REF", "No Product record exists in VFI Track.  H&M did not send an I1 file for this product."]
      end

      it "generates spreadsheet if tariff is missing" do
        invoice.invoice_lines.first.hts_number = nil

        spreadsheet = subject.generate_missing_parts_spreadsheet invoice
        expect(spreadsheet).not_to be_nil
        data = xlsx_data(spreadsheet, sheet_name: "INV Exceptions")
        expect(data[1]).to eq ["12345", "PO", "CN", "DESC", "6115.95.0000", nil, 9.99, "MID", "12345", "REF", "Use Part Number and the H&M Order # (Invoice Number in US Entry) to lookup the missing information from the source US Entry."]
      end

      it "generates spreadsheet if MID is missing" do
        invoice.invoice_lines.first.mid = nil

        spreadsheet = subject.generate_missing_parts_spreadsheet invoice
        expect(spreadsheet).not_to be_nil
        data = xlsx_data(spreadsheet, sheet_name: "INV Exceptions")
        expect(data[1]).to eq ["12345", "PO", "CN", "DESC", "6115.95.0000", nil, 9.99, nil, "12345", "REF", "Use Part Number and the H&M Order # (Invoice Number in US Entry) to lookup the missing information from the source US Entry."]
      end
    end
  end

  describe "generate_invoice_addendum" do
    let (:country) { us }
    let (:importer) { product_importer }
    let (:invoice) {
      invoice = Invoice.create! invoice_number: "INV", importer_id: importer.id, invoice_total_foreign: BigDecimal("199.8"), net_weight: BigDecimal("2")
      invoice_line = invoice.invoice_lines.create! part_number: "12345", part_description: "DESC", product_id: product.id, country_origin_id: cn.id, customer_reference_number: "PO", mid: "MID", hts_number: "1234567890", net_weight: BigDecimal("1"), net_weight_uom: "KG", quantity: BigDecimal("10"), value_foreign: BigDecimal("99.90"), unit_price: BigDecimal("9.99")
      invoice_line = invoice.invoice_lines.create! part_number: "12345", part_description: "DESC", product_id: product.id, country_origin_id: cn.id, customer_reference_number: "PO", mid: "MID", hts_number: "1234567890", net_weight: BigDecimal("1"), net_weight_uom: "KG", quantity: BigDecimal("10"), value_foreign: BigDecimal("99.90"), unit_price: BigDecimal("9.99")
      invoice
    }

    it "builds an xlsx spreadsheet using invoice data" do
      spreadsheet = subject.generate_invoice_addendum invoice
      data = xlsx_data(spreadsheet, sheet_name: "INV")
      expect(data.length).to eq 4
      expect(data[0]).to eq ["Shipment ID", "Part Number", "Description", "MID", "Country of Origin", "HTS", "Net Weight", "Net Weight UOM", "Unit Price", "Quantity", "Total Value"]
      expect(data[1]).to eq ["INV", "12345", "DESC", "MID", "CN", "1234.56.7890", 1.0, "KG", 9.99, 10, 99.90]
      expect(data[2]).to eq ["INV", "12345", "DESC", "MID", "CN", "1234.56.7890", 1.0, "KG", 9.99, 10, 99.90]
      expect(data[3]).to eq [nil, nil, nil, nil, nil, nil, 2.0, nil, nil, 20, 199.8]
    end
  end

  describe "make_pdf_info" do 
    let (:country) { us }
    let (:importer) { product_importer }
    let (:invoice) {
      invoice = Invoice.new invoice_number: "INV", invoice_date: Date.new(2019, 1, 17), importer_id: importer.id, invoice_total_foreign: BigDecimal("199.8"), net_weight: BigDecimal("2"), gross_weight: BigDecimal("1.5555")
      invoice_line = invoice.invoice_lines.build carrier_name: "CARRIER", part_number: "12345", part_description: "DESC", product_id: product.id, country_origin_id: cn.id, customer_reference_number: "PO", mid: "MID", hts_number: "1234567890", net_weight: BigDecimal("1"), net_weight_uom: "KG", quantity: BigDecimal("10"), value_foreign: BigDecimal("99.90"), unit_price: BigDecimal("9.99")
      invoice
    }

    it "builds pdf data" do
      d = subject.make_pdf_info invoice
      expect(d.control_number).to eq "INV"
      expect(d.exporter_reference).to eq "INV"
      expect(d.export_date).to eq Date.new(2019, 1, 17)
      expect(d.exporter_address.name).to eq "Geodis"
      expect(d.exporter_address.line_1).to eq "300 Kennedy Rd S Unit B"
      expect(d.exporter_address.line_2).to eq "Brampton, ON, L6W 4V2"
      expect(d.exporter_address.line_3).to eq "Canada"

      expect(d.firm_address.name).to eq "Geodis"
      expect(d.firm_address.line_1).to eq "281 AirTech Pkwy. Suite 191"
      expect(d.firm_address.line_2).to eq "Plainfield, IN 46168"
      expect(d.firm_address.line_3).to eq "USA"

      expect(d.consignee_address.name).to eq "H&M Hennes & Mauritz"
      expect(d.consignee_address.line_1).to eq "1600 River Road, Building 1"
      expect(d.consignee_address.line_2).to eq "Burlington Township, NJ 08016"
      expect(d.consignee_address.line_3).to eq "(609) 239-8703"

      expect(d.terms).to eq "FOB Windsor Ontario"
      expect(d.origin).to eq "Ontario"
      expect(d.destination).to eq "Indiana"
      expect(d.local_carrier).to eq "CARRIER"
      expect(d.export_carrier).to eq "CARRIER"
      expect(d.port_of_entry).to eq "Detroit, MI"
      expect(d.lading_location).to eq "Ontario"
      expect(d.related).to eq false
      expect(d.duty_for).to eq "Consignee"
      expect(d.date_of_sale).to eq Date.new(2019, 1, 17)
      expect(d.total_packages).to eq "10 Packages"
      expect(d.total_gross_weight).to eq "1.56 KG"
      expect(d.description_of_goods).to eq "For Customs Clearance by: Vandegrift\nFor the account of: H & M HENNES & MAURITZ L.P.\nMail order goods being returned by the Canadian\nConsumer for credit or exchange."
      expect(d.export_reason).to eq "Not Sold"
      expect(d.mode_of_transport).to eq "Road"
      expect(d.containerized).to eq false
      expect(d.owner_agent).to eq "Agent"
      expect(d.invoice_total).to eq "$199.80"
      expect(d.employee).to eq "Shahzad Dad"
    end
  end
end 
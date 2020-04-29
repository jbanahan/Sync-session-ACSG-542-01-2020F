describe OpenChain::CustomHandler::Amazon::AmazonBillingFileGenerator do

  def snapshot obj
    JSON.parse(CoreModule.find_by_object(obj).entity_json(obj))
  end

  def expect_ref xml, number_type, number_value
     expect(xml).to have_xpath_value("LoadLevel/Reference[ReferenceNumberType = '#{number_type}']/ReferenceNumber", "#{number_value}")
  end

  let! (:lading_port) { Factory(:port, schedule_k_code: "12345", name: "LADING PORT") }
  let! (:entry_port) { Factory(:port, schedule_d_code: "9999", name: "ENTRY PORT") }

  let! (:us) { Factory(:country, iso_code: "US") }
  let! (:mid) {
    ManufacturerId.create! mid: "MID1234", name: "MID", address_1: "123 Fake St", address_2: "STE 123", city: "Fakesville", postal_code: "12345", country: "XX"
  }

  let! (:master_company) { Factory(:master_company) }

  let (:entry) {
   Factory(
            :entry, customer_number: "AMZN-98765", entry_number: "ENTRYNUM", broker_reference: "12345", transport_mode_code: "10", mfids: "#{mid.mid}\n MID4567", release_date: Time.zone.parse("2019-07-31 00:00"),
            ult_consignee_name: "Consignee", consignee_address_1: "742 Evergreen Terrace", consignee_address_2: "Attn: Homer Simpson", consignee_city: "Springfield", consignee_state: "XX", consignee_postal_code: "XXXXX", consignee_country_code: "US",
            carrier_code: "SCAC", master_bills_of_lading: "MASTERBILL", house_bills_of_lading: "HOUSEBILL", total_packages: 100, entry_filed_date: Time.zone.parse("2019-07-30 12:00"), customer_references: "REF\n AMZD12345\n REF2",
            fcl_lcl: "FCL", lading_port_code: "12345", entry_port_code: "9999"
          )
  }

  let (:broker_invoice) {
    i = entry.broker_invoices.create!(invoice_number: "12345", invoice_date: Date.new(2019, 8, 1), invoice_total: BigDecimal("500"), currency: "USD",
      customer_number: "AMZN", bill_to_name: "Bill Me", bill_to_address_1: "100 IOU Ave", bill_to_address_2: "STE 100", bill_to_city: "Billsville",
      bill_to_state: "PA", bill_to_zip: "09876", bill_to_country_id: us.id
    )
    i.broker_invoice_lines.create! charge_code: "0001", charge_amount: BigDecimal("175"), charge_description: "DUTY"
    i.broker_invoice_lines.create! charge_code: "0007", charge_amount: BigDecimal("75"), charge_description: "Brokerage"
    i.broker_invoice_lines.create! charge_code: "0191", charge_amount: BigDecimal("25"), charge_description: "ISF"
    i
  }

  describe "generate_and_send_invoice_xml" do
    let (:sent_xml) { [] }
    let (:sent_filenames) { [] }
    let (:sent_sync_records) { [] }

    before :each do
      allow(subject).to receive(:ftp_sync_file) do |xml, sr|
        sent_filenames << xml.original_filename
        sent_sync_records << sr
        sent_xml << xml.read
      end
    end

    it "sends invoice xml file for duty" do
      now = Time.zone.parse("2019-08-01 12:31:30")
      Timecop.freeze(now) {
        subject.generate_and_send_invoice_xml(snapshot(entry), snapshot(broker_invoice), broker_invoice, :duty)
      }

      expect(sent_xml.length).to eq 1
      expect(sent_filenames.first).to eq "Invoice_DMCQ_12345_20190801123130_ecad9e66.xml"

      xml = REXML::Document.new(sent_xml.first).root

      expect(xml.name).to eq "Transmission"
      expect(xml).to have_xpath_value("sendingPartyID", "DMCQ")
      expect(xml).to have_xpath_value("receivingPartyID", "AMAZON")
      expect(xml).to have_xpath_value("transmissionControlNumber", "15646626900")
      expect(xml).to have_xpath_value("transmissionCreationDate", "20190801083130")
      expect(xml).to have_xpath_value("messageCount", "1")
      expect(xml).to have_xpath_value("isTest", "1")
      expect(xml).to have_xpath_value("Message/@seq", "1")

      m = xml.elements["Message"]
      expect(m).not_to be_nil

      expect(m).to have_xpath_value("sendingPartyID", "DMCQ")
      expect(m).to have_xpath_value("receivingPartyID", "AMAZON")
      expect(m).to have_xpath_value("messageControlNumber", "15646626900")
      expect(m).to have_xpath_value("messageCreationDate", "20190801083130")
      expect(m).to have_xpath_value("processType", "INVOICE")
      expect(m).to have_xpath_value("messageType", "US_CIV")
      expect(m).to have_xpath_value("InvoiceNumber", "12345_D")
      expect(m).to have_xpath_value("InvoiceDate", "20190801")
      # This is rolled back a day, due to the timzone used being US Eastern
      expect(m).to have_xpath_value("ShippedDate", "20190730")
      expect(m).to have_xpath_value("ShipmentMethodOfPayment", "CONTRACT")
      expect(m).to have_xpath_value("CurrencyCode", "USD")
      expect(m).to have_xpath_value("accountNumber", "USMAEUGIFTDUTOCE")
      expect(m).to have_xpath_value("CarrierNumber", "USMAEUGIFTDUTOCE")

      expect(m).to have_xpath_value("CarrierName", "Vandegrift, Inc.")
      expect(m).to have_xpath_value("CarrierAddress1", "100 Walnut Ave")
      expect(m).to have_xpath_value("CarrierAddress2", "Suite 600")
      expect(m).to have_xpath_value("CarrierCity", "Clark")
      expect(m).to have_xpath_value("CarrierStateOrProvinceCode", "NJ")
      expect(m).to have_xpath_value("CarrierPostalCode", "07066")
      expect(m).to have_xpath_value("CarrierCountryCode", "US")

      expect(m).to have_xpath_value("BillToName", "Bill Me")
      expect(m).to have_xpath_value("BillToAddress1", "100 IOU Ave")
      expect(m).to have_xpath_value("BillToAddress2", "STE 100")
      expect(m).to have_xpath_value("BillToCity", "Billsville")
      expect(m).to have_xpath_value("BillToStateOrProvinceCode", "PA")
      expect(m).to have_xpath_value("BillToPostalCode", "09876")
      expect(m).to have_xpath_value("BillToCountryCode", "US")

      expect(m).to have_xpath_value("TermsNetDueDate", "20190816")

      expect(m).to have_xpath_value("LoadLevel/ShipFromAddressEntityCode", "SH")
      expect(m).to have_xpath_value("LoadLevel/ShipFromName", "MID")
      expect(m).to have_xpath_value("LoadLevel/ShipFromAddress1", "123 Fake St")
      expect(m).to have_xpath_value("LoadLevel/ShipFromAddress2", "STE 123")
      expect(m).to have_xpath_value("LoadLevel/ShipFromCity", "Fakesville")
      expect(m).to have_xpath_value("LoadLevel/ShipFromStateOrProvinceCode", nil)
      expect(m).to have_xpath_value("LoadLevel/ShipFromPostalCode", "12345")
      expect(m).to have_xpath_value("LoadLevel/ShipFromCountryCode", "XX")

      expect(m).to have_xpath_value("LoadLevel/ConsigneeAddressEntityCode", "CN")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeName", "Consignee")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeAddress1", "742 Evergreen Terrace")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeAddress2", "Attn: Homer Simpson")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeCity", "Springfield")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeStateOrProvinceCode", "XX")
      expect(m).to have_xpath_value("LoadLevel/ConsigneePostalCode", "XXXXX")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeCountryCode", "US")

      expect(m).to have_xpath_value("LoadLevel/StandardCarrierCode", "DMCQ")

      expect(m).to have_xpath_value("count(LoadLevel/Reference)", 11)
      expect_ref(m, 'TENDERID', "DCD_DMCQAMZD12345")
      expect_ref(m, 'MBL', "AMZD12345")
      expect_ref(m, 'HBL', "HOUSEBILL")
      expect_ref(m, 'SHIPMODE', "OCEAN")
      expect_ref(m, 'ORIGINPORT', "LADING PORT")
      expect_ref(m, 'DESTINATIONPORT', "ENTRY PORT")
      expect_ref(m, 'CONSIGNMENT', "100")
      expect_ref(m, "ENTRYSTARTDATE", "20190730")
      expect_ref(m, "ENTRYENDDATE", "20190730")
      expect_ref(m, "SERVICETYPE", "DUTY")
      expect_ref(m, "ENTRYID", "ENTRYNUM")

      expect(m).to have_xpath_value("count(LoadLevel/Cost)", 1)

      expect(m).to have_xpath_value("LoadLevel/Cost/ExtraCost", "175.0")
      expect(m).to have_xpath_value("LoadLevel/Cost/ExtraCostDefinition", "DUT")

      expect(m).to have_xpath_value("Summary/NetAmount", "175.0")
      expect(m).to have_xpath_value("Summary/TotalMonetarySummary", "175.0")

      sr = broker_invoice.sync_records.first
      expect(sr.trading_partner).to eq "AMZN BILLING DUTY"
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i
    end

    it "sends invoice xml file for brokerage" do
      now = Time.zone.parse("2019-08-01 12:31:30")
      Timecop.freeze(now) {
        subject.generate_and_send_invoice_xml(snapshot(entry), snapshot(broker_invoice), broker_invoice, :brokerage)
      }

      expect(sent_xml.length).to eq 1
      expect(sent_filenames.first).to eq "Invoice_DMCQ_12345_20190801123130_ecad9e66.xml"

      xml = REXML::Document.new(sent_xml.first).root

      expect(xml.name).to eq "Transmission"
      expect(xml).to have_xpath_value("sendingPartyID", "DMCQ")
      expect(xml).to have_xpath_value("receivingPartyID", "AMAZON")
      expect(xml).to have_xpath_value("transmissionControlNumber", "15646626900")
      expect(xml).to have_xpath_value("transmissionCreationDate", "20190801083130")
      expect(xml).to have_xpath_value("messageCount", "1")
      expect(xml).to have_xpath_value("isTest", "1")
      expect(xml).to have_xpath_value("Message/@seq", "1")

      m = xml.elements["Message"]
      expect(m).not_to be_nil

      expect(m).to have_xpath_value("sendingPartyID", "DMCQ")
      expect(m).to have_xpath_value("receivingPartyID", "AMAZON")
      expect(m).to have_xpath_value("messageControlNumber", "15646626900")
      expect(m).to have_xpath_value("messageCreationDate", "20190801083130")
      expect(m).to have_xpath_value("processType", "INVOICE")
      expect(m).to have_xpath_value("messageType", "US_CIV")
      expect(m).to have_xpath_value("InvoiceNumber", "12345_B")
      expect(m).to have_xpath_value("InvoiceDate", "20190801")
      # This is rolled back a day, due to the timzone used being US Eastern
      expect(m).to have_xpath_value("ShippedDate", "20190730")
      expect(m).to have_xpath_value("ShipmentMethodOfPayment", "CONTRACT")
      expect(m).to have_xpath_value("CurrencyCode", "USD")
      expect(m).to have_xpath_value("accountNumber", "USMAEUGIFTCUBROCECYFCL")
      expect(m).to have_xpath_value("CarrierNumber", "USMAEUGIFTCUBROCECYFCL")

      expect(m).to have_xpath_value("CarrierName", "Vandegrift, Inc.")
      expect(m).to have_xpath_value("CarrierAddress1", "100 Walnut Ave")
      expect(m).to have_xpath_value("CarrierAddress2", "Suite 600")
      expect(m).to have_xpath_value("CarrierCity", "Clark")
      expect(m).to have_xpath_value("CarrierStateOrProvinceCode", "NJ")
      expect(m).to have_xpath_value("CarrierPostalCode", "07066")
      expect(m).to have_xpath_value("CarrierCountryCode", "US")

      expect(m).to have_xpath_value("BillToName", "Bill Me")
      expect(m).to have_xpath_value("BillToAddress1", "100 IOU Ave")
      expect(m).to have_xpath_value("BillToAddress2", "STE 100")
      expect(m).to have_xpath_value("BillToCity", "Billsville")
      expect(m).to have_xpath_value("BillToStateOrProvinceCode", "PA")
      expect(m).to have_xpath_value("BillToPostalCode", "09876")
      expect(m).to have_xpath_value("BillToCountryCode", "US")

      expect(m).to have_xpath_value("TermsNetDueDate", "20190816")

      expect(m).to have_xpath_value("LoadLevel/ShipFromAddressEntityCode", "SH")
      expect(m).to have_xpath_value("LoadLevel/ShipFromName", "MID")
      expect(m).to have_xpath_value("LoadLevel/ShipFromAddress1", "123 Fake St")
      expect(m).to have_xpath_value("LoadLevel/ShipFromAddress2", "STE 123")
      expect(m).to have_xpath_value("LoadLevel/ShipFromCity", "Fakesville")
      expect(m).to have_xpath_value("LoadLevel/ShipFromStateOrProvinceCode", nil)
      expect(m).to have_xpath_value("LoadLevel/ShipFromPostalCode", "12345")
      expect(m).to have_xpath_value("LoadLevel/ShipFromCountryCode", "XX")

      expect(m).to have_xpath_value("LoadLevel/ConsigneeAddressEntityCode", "CN")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeName", "Consignee")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeAddress1", "742 Evergreen Terrace")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeAddress2", "Attn: Homer Simpson")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeCity", "Springfield")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeStateOrProvinceCode", "XX")
      expect(m).to have_xpath_value("LoadLevel/ConsigneePostalCode", "XXXXX")
      expect(m).to have_xpath_value("LoadLevel/ConsigneeCountryCode", "US")

      expect(m).to have_xpath_value("LoadLevel/StandardCarrierCode", "DMCQ")

      expect(m).to have_xpath_value("count(LoadLevel/Reference)", 11)
      expect_ref(m, 'TENDERID', "DCB_DMCQAMZD12345")
      expect_ref(m, 'MBL', "AMZD12345")
      expect_ref(m, 'HBL', "HOUSEBILL")
      expect_ref(m, 'SHIPMODE', "OCEAN")
      expect_ref(m, 'ORIGINPORT', "LADING PORT")
      expect_ref(m, 'DESTINATIONPORT', "ENTRY PORT")
      expect_ref(m, 'CONSIGNMENT', "100")
      expect_ref(m, "ENTRYSTARTDATE", "20190730")
      expect_ref(m, "ENTRYENDDATE", "20190730")
      expect_ref(m, "SERVICETYPE", "Import Customs Clearance")
      expect_ref(m, "CONTAINERID", "ENTRYNUM")

      expect(m).to have_xpath_value("count(LoadLevel/Cost)", 2)

      expect(m).to have_xpath_value("LoadLevel/Cost[ExtraCostDefinition = 'CUS']/ExtraCost", "75.0")
      expect(m).to have_xpath_value("LoadLevel/Cost[ExtraCostDefinition = 'ISF']/ExtraCost", "25.0")

      expect(m).to have_xpath_value("Summary/NetAmount", "100.0")
      expect(m).to have_xpath_value("Summary/TotalMonetarySummary", "100.0")

      sr = broker_invoice.sync_records.first
      expect(sr.trading_partner).to eq "AMZN BILLING BROKERAGE"
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i
    end

    it "uses existing AR address" do
      address = Factory(:address, company: master_company, system_code: "Accounts Receivable", name: "Alternate Address", line_1: "123 ADDR", line_2: "456 ADDR", city: "Altown", state: "AL", postal_code: "ALT", country: us)

      subject.generate_and_send_invoice_xml(snapshot(entry), snapshot(broker_invoice), broker_invoice, :brokerage)

      xml = REXML::Document.new(sent_xml.first).root

      expect(xml).to have_xpath_value("Message/CarrierName", "Alternate Address")
      expect(xml).to have_xpath_value("Message/CarrierAddress1", "123 ADDR")
      expect(xml).to have_xpath_value("Message/CarrierAddress2", "456 ADDR")
      expect(xml).to have_xpath_value("Message/CarrierCity", "Altown")
      expect(xml).to have_xpath_value("Message/CarrierStateOrProvinceCode", "AL")
      expect(xml).to have_xpath_value("Message/CarrierPostalCode", "ALT")
      expect(xml).to have_xpath_value("Message/CarrierCountryCode", "US")
    end

    [["10", "FCL", "USMAEUGIFTCUBROCECYFCL"], ["10", "LCL", "USMAEUGIFTCUBROCECFS"], ["40", "Air", "USMAEUGIFTCUBRAIR"]].each do |params|
      it "uses correct brokerage CarrierNumber for #{params[0]} mode #{params[1]} entries" do
        entry.transport_mode_code = params[0]
        entry.fcl_lcl = params[1]

        subject.generate_and_send_invoice_xml(snapshot(entry), snapshot(broker_invoice), broker_invoice, :brokerage)
        expect(REXML::Document.new(sent_xml.first).root).to have_xpath_value("Message/CarrierNumber", params[2])
      end
    end

    [["10", "FCL", "USMAEUGIFTDUTOCE"], ["10", "LCL", "USMAEUGIFTDUTOCE"], ["40", "Air", "USMAEUGIFTDUTAIR"]].each do |params|
      it "uses correct duty CarrierNumber for #{params[0]} mode #{params[1]} entries" do
        entry.transport_mode_code = params[0]
        entry.fcl_lcl = params[1]

        subject.generate_and_send_invoice_xml(snapshot(entry), snapshot(broker_invoice), broker_invoice, :duty)
        expect(REXML::Document.new(sent_xml.first).root).to have_xpath_value("Message/CarrierNumber", params[2])
      end
    end

    it "errors if invalid charge code is used" do
      broker_invoice.broker_invoice_lines.create! charge_code: "123", charge_amount: 100, charge_description: "ABC"
      expect { subject.generate_and_send_invoice_xml(snapshot(entry), snapshot(broker_invoice), broker_invoice, :brokerage) }.to raise_error "Invoice 12345 has an invalid Charge Code of '123'. Only pre-validated charge codes can be billed to Amazon. This invoice must be reversed and re-issued without the invalid code."
    end

    it "uses secondary MID if first is not found" do
      mid.destroy
      mid2 = ManufacturerId.create! mid: "MID4567", name: "MID2", address_1: "567 Fake St", address_2: "STE 567", city: "Faketown", postal_code: "98765", country: "YY"

      subject.generate_and_send_invoice_xml(snapshot(entry), snapshot(broker_invoice), broker_invoice, :brokerage)

      xml = REXML::Document.new(sent_xml.first).root
      expect(xml).to have_xpath_value("Message/LoadLevel/ShipFromName", "MID2")
      expect(xml).to have_xpath_value("Message/LoadLevel/ShipFromAddress1", "567 Fake St")
      expect(xml).to have_xpath_value("Message/LoadLevel/ShipFromAddress2", "STE 567")
      expect(xml).to have_xpath_value("Message/LoadLevel/ShipFromCity", "Faketown")
      expect(xml).to have_xpath_value("Message/LoadLevel/ShipFromStateOrProvinceCode", nil)
      expect(xml).to have_xpath_value("Message/LoadLevel/ShipFromPostalCode", "98765")
      expect(xml).to have_xpath_value("Message/LoadLevel/ShipFromCountryCode", "YY")
    end

    it "defaults to USD if currency is not present in broker invoice" do
      broker_invoice.update! currency: nil

      subject.generate_and_send_invoice_xml(snapshot(entry), snapshot(broker_invoice), broker_invoice, :brokerage)

      xml = REXML::Document.new(sent_xml.first).root
      expect(xml).to have_xpath_value("Message/CurrencyCode", "USD")
    end

    it "sends air invoices" do
      entry.update! transport_mode_code: "40", fcl_lcl: nil

      subject.generate_and_send_invoice_xml(snapshot(entry), snapshot(broker_invoice), broker_invoice, :brokerage)

      xml = REXML::Document.new(sent_xml.first).root
      m = xml.elements["Message"]
      # The only thing different about air invoices are the data in the references
      expect(m).to have_xpath_value("count(LoadLevel/Reference)", 9)
      expect_ref(m, 'TENDERID', "DCB_DMCQHOUSEBILL")
      expect_ref(m, 'AWB', "HOUSEBILL")
      expect_ref(m, 'SHIPMODE', "AIR")
      expect_ref(m, 'ORIGINPORT', "LADING PORT")
      expect_ref(m, 'DESTINATIONPORT', "ENTRY PORT")
      expect_ref(m, "ENTRYSTARTDATE", "20190730")
      expect_ref(m, "ENTRYENDDATE", "20190730")
      expect_ref(m, "SERVICETYPE", "Import Customs Clearance")
      expect_ref(m, "ENTRYID", "ENTRYNUM")
    end

    it "sends lcl invoices" do
      entry.update! fcl_lcl: "LCL"

      subject.generate_and_send_invoice_xml(snapshot(entry), snapshot(broker_invoice), broker_invoice, :brokerage)

      xml = REXML::Document.new(sent_xml.first).root
      m = xml.elements["Message"]
      # The only thing different about lcl invoices are the data in the references
      expect(m).to have_xpath_value("count(LoadLevel/Reference)", 11)
      expect_ref(m, 'TENDERID', "DCB_DMCQAMZD12345")
      expect_ref(m, 'MBL', "AMZD12345")
      expect_ref(m, 'HBL', "HOUSEBILL")
      expect_ref(m, 'SHIPMODE', "OCEAN")
      expect_ref(m, 'ORIGINPORT', "LADING PORT")
      expect_ref(m, 'DESTINATIONPORT', "ENTRY PORT")
      expect_ref(m, 'CONSIGNMENT', "100")
      expect_ref(m, "ENTRYSTARTDATE", "20190730")
      expect_ref(m, "ENTRYENDDATE", "20190730")
      expect_ref(m, "SERVICETYPE", "Import Customs Clearance")
      expect_ref(m, "ENTRYID", "ENTRYNUM")
    end
  end

  describe "generate_and_send_invoice_files" do
    let (:entry_snapshot) { snapshot(entry) }
    let (:invoice_snapshot) { snapshot(broker_invoice) }

    it "sends all invoices and records primary sync record" do
      expect(subject).to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :duty)
      expect(subject).to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :brokerage)

      now = Time.zone.now
      Timecop.freeze(now) {
        subject.generate_and_send_invoice_files entry_snapshot, invoice_snapshot, broker_invoice
      }

      sr = broker_invoice.sync_records.first
      expect(sr.trading_partner).to eq "AMZN BILLING"
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i
      expect(sr.failure_message).to be_nil
    end

    it "handles errors when sending an invoice" do
      expect(subject).to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :duty).and_raise(StandardError, "Error!")
      expect_any_instance_of(StandardError).to receive(:log_me).with(["Failed to generate duty invoice for Broker Invoice # 12345."])

      subject.generate_and_send_invoice_files entry_snapshot, invoice_snapshot, broker_invoice

      expect(broker_invoice.sync_records.length).to eq 1
      sr = broker_invoice.sync_records.first
      expect(sr.failure_message).to eq "Error!"
      expect(sr.trading_partner).to eq "AMZN BILLING DUTY"
      expect(sr).to be_persisted
    end

    it "does not send duty invoices if already sent" do
      broker_invoice.sync_records.create! trading_partner: "AMZN BILLING DUTY", sent_at: Time.zone.now

      expect(subject).not_to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :duty)
      expect(subject).to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :brokerage)

      subject.generate_and_send_invoice_files entry_snapshot, invoice_snapshot, broker_invoice
    end

    it "does not send brokerage invoices if already sent" do
      broker_invoice.sync_records.create! trading_partner: "AMZN BILLING BROKERAGE", sent_at: Time.zone.now

      expect(subject).not_to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :brokerage)
      expect(subject).to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :duty)

      subject.generate_and_send_invoice_files entry_snapshot, invoice_snapshot, broker_invoice
    end

    it "does not send duty invoices if the broker invoice does not have duty charges" do
      broker_invoice.broker_invoice_lines.find { |bi| bi.charge_code == "0001" }.destroy
      broker_invoice.reload

      expect(subject).not_to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :duty)
      expect(subject).to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :brokerage)

      subject.generate_and_send_invoice_files entry_snapshot, invoice_snapshot, broker_invoice

      sr = broker_invoice.sync_records.first
      expect(sr.trading_partner).to eq "AMZN BILLING"
    end

    it "does not send brokerage invoices if the broker invoice does not have brokerage charges" do
      broker_invoice.broker_invoice_lines.find_all { |bi| bi.charge_code != "0001" }.each &:destroy
      broker_invoice.reload

      expect(subject).to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :duty)
      expect(subject).not_to receive(:generate_and_send_invoice_xml).with(entry_snapshot, invoice_snapshot, broker_invoice, :brokerage)

      subject.generate_and_send_invoice_files entry_snapshot, invoice_snapshot, broker_invoice

      sr = broker_invoice.sync_records.first
      expect(sr.trading_partner).to eq "AMZN BILLING"
    end
  end

  describe "generate_and_send" do
    before :each do
      broker_invoice
      entry
    end

    let (:entry_snapshot) { snapshot(entry) }

    it "sends any unsent invoices" do
      expect(subject).to receive(:generate_and_send_invoice_files).with(entry_snapshot, instance_of(Hash), broker_invoice)
      subject.generate_and_send(entry_snapshot)
    end

    it "skips any invoices that are not billed to 'AMZN'" do
      broker_invoice.update! customer_number: "AMZN-98765"
      expect(subject).not_to receive(:generate_and_send_invoice_files)
      subject.generate_and_send(entry_snapshot)
    end

    it "skips invoices already marked as sent" do
      broker_invoice.sync_records.create! trading_partner: "AMZN BILLING", sent_at: Time.zone.now

      expect(subject).not_to receive(:generate_and_send_invoice_files)
      subject.generate_and_send(entry_snapshot)
    end

    it "skips entries without invoices" do
      broker_invoice.destroy
      entry.reload

      expect(subject).not_to receive(:generate_and_send_invoice_files)
      subject.generate_and_send(entry_snapshot)
    end

    context "data validations" do
      let! (:ms) { stub_master_setup }

      before :each do
        allow(ms).to receive(:production?).and_return true
      end

      after :each do
        expect(subject).not_to receive(:generate_and_send_invoice_files)
        subject.generate_and_send(entry_snapshot)
      end

      [:entry_port_code, :release_date, :mfids, :ult_consignee_name, :carrier_code, :transport_mode_code, :entry_filed_date].each do |field|
        it "skips entries without #{field} data" do
          entry.update! field => nil
        end
      end

      context "with ocean entry" do
        [:master_bills_of_lading, :fcl_lcl, :lading_port_code].each do |field|
          it "skips entries without #{field} data" do
            entry.update! field => nil
          end
        end

        it "skips entries without Amazon Bill of Lading" do
          entry.update! customer_references: "REF"
        end
      end

      context "with air entry" do
        before :each do
          entry.update! transport_mode_code: "40"
        end

        [:house_bills_of_lading].each do |field|
          it "skips entries without #{field} data" do
            entry.update! field => nil
          end
        end
      end
    end

    it "skips entries without release dates" do
      entry.update! release_date: nil
      entry.reload

      expect(subject).not_to receive(:generate_and_send_invoice_files)
      subject.generate_and_send(entry_snapshot)
    end

    it "skips entries with failed business rules" do
      expect(subject).to receive(:mf).with(entry_snapshot, "ent_failed_business_rules").and_return "failed rule"

      expect(subject).not_to receive(:generate_and_send_invoice_files)
      subject.generate_and_send(entry_snapshot)
    end

    it "skips entries without carrier codes" do
      entry.update! carrier_code: nil
      entry.reload

      expect(subject).not_to receive(:generate_and_send_invoice_files)
      subject.generate_and_send(entry_snapshot)
    end

    it "skips entries without ultimate consignee names" do
      entry.update! ult_consignee_name: nil
      entry.reload

      expect(subject).not_to receive(:generate_and_send_invoice_files)
      subject.generate_and_send(entry_snapshot)
    end

    it "skips entries without MIDS" do
      entry.update! mfids: nil
      entry.reload

      expect(subject).not_to receive(:generate_and_send_invoice_files)
      subject.generate_and_send(entry_snapshot)
    end

    it "skips entries without transport mode codes" do
      entry.update! transport_mode_code: nil
      entry.reload

      expect(subject).not_to receive(:generate_and_send_invoice_files)
      subject.generate_and_send(entry_snapshot)
    end
  end
end
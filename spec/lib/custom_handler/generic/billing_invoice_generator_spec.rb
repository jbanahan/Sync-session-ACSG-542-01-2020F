describe OpenChain::CustomHandler::Generic::BillingInvoiceGenerator do

  describe "generate_xml" do
    it "generates an XML" do
      usa = Factory(:country, iso_code: "US", name: "United MF States")
      broker = Factory(:company, name: "Vandegrift Forwarding Co.", broker: true)
      broker.addresses.create!(address_type: "Remit To", name: "Vandegrift Inc.", line_1: "123 Fake St",
                               line_2: "Suite 270", city: "Fakesville", state: "NJ", postal_code: "01234", country_id: usa.id)
      broker.system_identifiers.create!(system: "Filer Code", code: "316")

      tz = ActiveSupport::TimeZone['UTC']
      port_lading_address = Factory(:address, line_1: "123 Fake Ln", line_2: "Suite 555", line_3: "Mailbox X", city: "Ladingsville",
                                              state: "ND", postal_code: "56836", country_id: usa.id)
      Factory(:port, schedule_k_code: "14001", name: "Land-O-Lading", address: port_lading_address)
      Factory(:port, schedule_d_code: "1401", name: "Unladingston", address: nil)
      port_entry_address = Factory(:address, line_1: "123 Fake Cir", line_2: "Suite 557", city: "Entry City", state: "MS",
                                             postal_code: "76836", country_id: nil)
      Factory(:port, schedule_d_code: "1402", name: "Entry City", address: port_entry_address)
      # The accented characters in this name should be replaced in the output by their non-accented counterparts.
      Factory(:port, iata_code: "ALF", name: "Äírpørt", address: nil)

      entry = Factory(:entry, entry_number: "31679758714", entry_type: "01", broker_reference: "ARGH58285",
                              lading_port_code: "14001", unlading_port_code: "1401", location_of_goods: "M801",
                              export_date: Date.new(2020, 3, 29), release_date: tz.parse('2020-04-28 09:25:01'),
                              arrival_date: tz.parse('2020-04-29 08:15:51'), import_date: Date.new(2020, 4, 30),
                              vessel: "EVER LYRIC", customer_number: "KRAFT", voyage: "6837kj3e",
                              ult_consignee_name: "Consignco", consignee_address_1: "456 Fake St", consignee_address_2: "Suite 765",
                              consignee_city: "Faketown", consignee_state: "PA", consignee_postal_code: "10293", consignee_country_code: "CA",
                              vendor_names: "Vend1\n Vend2", transport_mode_code: "10", entry_filed_date: tz.parse('2020-05-03 12:55:31'),
                              carrier_code: "ALPO", merchandise_description: "rubber baby buggy bumpers",
                              origin_country_codes: "CN\n VN", export_country_codes: "IN\n HK",
                              master_bills_of_lading: "ABC\n DEF", house_bills_of_lading: "DEF\n GHI", it_numbers: "GHI\n JKL",
                              customer_references: "JKL\n MNO", po_numbers: "MNO\n PQR", entry_port_code: "1402",
                              origin_airport_code: "ALF")
      bi = entry.broker_invoices.create! customer_number: "KRAANG", invoice_number: "INV2828", invoice_date: Date.new(2020, 5, 1),
                                         invoice_total: BigDecimal("20.02"), currency: "CAD", fiscal_year: 2020, fiscal_month: 3,
                                         bill_to_name: "Bill II", bill_to_address_1: "789 Fake St", bill_to_address_2: "Suite 16",
                                         bill_to_city: "Fakesburg", bill_to_state: "MD", bill_to_zip: "67677", bill_to_country_id: usa.id
      bi.broker_invoice_lines.create! charge_code: "0099", charge_amount: BigDecimal("29.95"), charge_description: "Charge-1",
                                      vendor_name: "VendA", vendor_reference: "AB67CD"
      bi.broker_invoice_lines.create! charge_code: "0100", charge_amount: BigDecimal("39.95"), charge_description: "Charge-2",
                                      vendor_name: "VendB", vendor_reference: "AB67EF"
      bi.broker_invoice_lines.create! charge_code: "0600", charge_amount: BigDecimal("49.95"), charge_description: "Charge-3",
                                      vendor_name: "VendC", vendor_reference: "AB67GH"
      entry.containers.create! container_number: "CONT102938", container_size: "40FT", fcl_lcl: "FCL", weight: 2200, quantity: 3, uom: "PCS", teus: 5
      entry.containers.create! container_number: "CONT102939", container_size: "41FT", fcl_lcl: "LCL", weight: 2201, quantity: 4, uom: "PCP", teus: 6

      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")
      doc = nil
      Timecop.freeze(current) do
        doc = subject.generate_xml bi
      end

      elem_root = doc.root
      expect(elem_root.name).to eq "BillingInvoices"

      elem_doc_info = elem_root.elements.to_a("DocumentInfo")[0]
      expect(elem_doc_info).not_to be_nil
      expect(elem_doc_info.text("DocumentSender")).to eq "VFITRACK"
      expect(elem_doc_info.text("DocumentRecipient")).to eq "KRAANG"
      expect(elem_doc_info.text("CreatedAt")).to eq "2020-03-24T02:05:08-0400"

      elem_billing_invoice = elem_root.elements.to_a("BillingInvoice")[0]
      expect(elem_billing_invoice).not_to be_nil
      expect(elem_billing_invoice.text("InvoiceNumber")).to eq "INV2828"
      expect(elem_billing_invoice.text("InvoiceDate")).to eq "2020-05-01"
      expect(elem_billing_invoice.text("InvoiceTotal")).to eq "20.02"
      expect(elem_billing_invoice.text("Currency")).to eq "CAD"
      expect(elem_billing_invoice.text("CustomerNumber")).to eq "KRAANG"
      expect(elem_billing_invoice.text("FiscalYear")).to eq "2020"
      expect(elem_billing_invoice.text("FiscalMonth")).to eq "3"

      elem_remit_to = elem_billing_invoice.elements.to_a("RemitTo")[0]
      expect(elem_remit_to).not_to be_nil
      expect(elem_remit_to.text("Name")).to eq "Vandegrift Inc."
      expect(elem_remit_to.text("Address1")).to eq "123 Fake St"
      expect(elem_remit_to.text("Address2")).to eq "Suite 270"
      expect(elem_remit_to.text("City")).to eq "Fakesville"
      expect(elem_remit_to.text("State")).to eq "NJ"
      expect(elem_remit_to.text("PostalCode")).to eq "01234"
      expect(elem_remit_to.text("Country")).to eq "US"

      elem_consignee = elem_billing_invoice.elements.to_a("Consignee")[0]
      expect(elem_consignee).not_to be_nil
      expect(elem_consignee.text("Name")).to eq "Consignco"
      expect(elem_consignee.text("Address1")).to eq "456 Fake St"
      expect(elem_consignee.text("Address2")).to eq "Suite 765"
      expect(elem_consignee.text("City")).to eq "Faketown"
      expect(elem_consignee.text("State")).to eq "PA"
      expect(elem_consignee.text("PostalCode")).to eq "10293"
      expect(elem_consignee.text("Country")).to eq "CA"

      elem_bill_to = elem_billing_invoice.elements.to_a("BillTo")[0]
      expect(elem_bill_to).not_to be_nil
      expect(elem_bill_to.text("Name")).to eq "Bill II"
      expect(elem_bill_to.text("Address1")).to eq "789 Fake St"
      expect(elem_bill_to.text("Address2")).to eq "Suite 16"
      expect(elem_bill_to.text("City")).to eq "Fakesburg"
      expect(elem_bill_to.text("State")).to eq "MD"
      expect(elem_bill_to.text("PostalCode")).to eq "67677"
      expect(elem_bill_to.text("Country")).to eq "US"

      expect(elem_billing_invoice.elements.to_a("BillingInvoiceLine").length).to eq 3
      elem_bill_line_1 = elem_billing_invoice.elements.to_a("BillingInvoiceLine")[0]
      expect(elem_bill_line_1.text("ChargeCode")).to eq "0099"
      expect(elem_bill_line_1.text("BilledAmount")).to eq "0"
      expect(elem_bill_line_1.text("DisplayAmount")).to eq "29.95"
      expect(elem_bill_line_1.text("ChargeDescription")).to eq "Charge-1"
      expect(elem_bill_line_1.text("VendorName")).to eq "Vend1,Vend2"
      expect(elem_bill_line_1.text("VendorReference")).to eq "AB67CD"

      elem_bill_line_2 = elem_billing_invoice.elements.to_a("BillingInvoiceLine")[1]
      expect(elem_bill_line_2.text("ChargeCode")).to eq "0100"
      expect(elem_bill_line_2.text("BilledAmount")).to eq "39.95"
      expect(elem_bill_line_2.text("DisplayAmount")).to eq "0"

      elem_bill_line_3 = elem_billing_invoice.elements.to_a("BillingInvoiceLine")[2]
      expect(elem_bill_line_3.text("ChargeCode")).to eq "0600"
      expect(elem_bill_line_3.text("BilledAmount")).to eq "0"
      expect(elem_bill_line_3.text("DisplayAmount")).to eq "49.95"

      elem_entry = elem_billing_invoice.elements.to_a("Entry")[0]
      expect(elem_entry).not_to be_nil
      expect(elem_entry.text("CustomerNumber")).to eq "KRAFT"
      expect(elem_entry.text("EntryNumber")).to eq "31679758714"
      expect(elem_entry.text("BrokerReference")).to eq "ARGH58285"
      expect(elem_entry.text("CustomsEntryType")).to eq "01"
      expect(elem_entry.text("ModeOfTransportation")).to eq "Sea"
      expect(elem_entry.text("CustomsModeOfTransportation")).to eq "10"
      expect(elem_entry.text("ExportDate")).to eq "2020-03-29"
      expect(elem_entry.text("ArrivalDate")).to eq "2020-04-29"
      expect(elem_entry.text("ImportDate")).to eq "2020-04-30"
      expect(elem_entry.text("EntryFiledDateTime")).to eq "2020-05-03T12:55:31+0000"
      expect(elem_entry.text("ReleaseDateTime")).to eq "2020-04-28T09:25:01+0000"
      expect(elem_entry.text("Vessel")).to eq "EVER LYRIC"
      expect(elem_entry.text("VoyageFlightNumber")).to eq "6837kj3e"
      expect(elem_entry.text("CarrierCode")).to eq "ALPO"
      expect(elem_entry.text("MerchandiseDescription")).to eq "rubber baby buggy bumpers"

      elem_countries_origin = elem_entry.elements.to_a("CountriesOfOrigin")[0]
      expect(elem_countries_origin).not_to be_nil
      expect(elem_countries_origin.elements.to_a("Country").length).to eq 2
      expect(elem_countries_origin.elements.to_a("Country")[0].text).to eq "CN"
      expect(elem_countries_origin.elements.to_a("Country")[1].text).to eq "VN"

      elem_countries_export = elem_entry.elements.to_a("CountriesOfExport")[0]
      expect(elem_countries_export).not_to be_nil
      expect(elem_countries_export.elements.to_a("Country").length).to eq 2
      expect(elem_countries_export.elements.to_a("Country")[0].text).to eq "IN"
      expect(elem_countries_export.elements.to_a("Country")[1].text).to eq "HK"

      elem_containers = elem_entry.elements.to_a("Containers")[0]
      expect(elem_containers).not_to be_nil
      expect(elem_containers.elements.to_a("Container").length).to eq 2
      elem_container_1 = elem_containers.elements.to_a("Container")[0]
      expect(elem_container_1.text("ContainerNumber")).to eq "CONT102938"
      expect(elem_container_1.text("ContainerSize")).to eq "40FT"
      expect(elem_container_1.text("LoadType")).to eq "FCL"
      expect(elem_container_1.text("Weight")).to eq "2200"
      expect(elem_container_1.text("WeightUom")).to eq "KG"
      expect(elem_container_1.text("Quantity")).to eq "3"
      expect(elem_container_1.text("QuantityUom")).to eq "PCS"
      expect(elem_container_1.text("Teus")).to eq "5"

      elem_container_2 = elem_containers.elements.to_a("Container")[1]
      expect(elem_container_2.text("ContainerNumber")).to eq "CONT102939"

      elem_reference_numbers = elem_entry.elements.to_a("ReferenceNumbers")[0]
      expect(elem_reference_numbers).not_to be_nil
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber").length).to eq 10
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[0].text("Code")).to eq "MasterBillOfLading"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[0].text("Value")).to eq "ABC"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[1].text("Code")).to eq "MasterBillOfLading"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[1].text("Value")).to eq "DEF"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[2].text("Code")).to eq "HouseBillOfLading"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[2].text("Value")).to eq "DEF"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[3].text("Code")).to eq "HouseBillOfLading"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[3].text("Value")).to eq "GHI"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[4].text("Code")).to eq "ItNumber"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[4].text("Value")).to eq "GHI"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[5].text("Code")).to eq "ItNumber"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[5].text("Value")).to eq "JKL"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[6].text("Code")).to eq "CustomerReference"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[6].text("Value")).to eq "JKL"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[7].text("Code")).to eq "CustomerReference"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[7].text("Value")).to eq "MNO"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[8].text("Code")).to eq "OrderNumber"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[8].text("Value")).to eq "MNO"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[9].text("Code")).to eq "OrderNumber"
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber")[9].text("Value")).to eq "PQR"

      elem_locations = elem_entry.elements.to_a("Locations")[0]
      expect(elem_locations).not_to be_nil
      expect(elem_locations.elements.to_a("Location").length).to eq 4

      elem_lading_port = elem_locations.elements.to_a("Location")[0]
      expect(elem_lading_port.text("LocationType")).to eq "PortOfLading"
      expect(elem_lading_port.text("LocationCode")).to eq "14001"
      expect(elem_lading_port.text("LocationCodeType")).to eq "ScheduleK"
      expect(elem_lading_port.text("Name")).to eq "Land-O-Lading"
      expect(elem_lading_port.text("Address1")).to eq "123 Fake Ln"
      expect(elem_lading_port.text("Address2")).to eq "Suite 555"
      expect(elem_lading_port.text("Address3")).to eq "Mailbox X"
      expect(elem_lading_port.text("City")).to eq "Ladingsville"
      expect(elem_lading_port.text("State")).to eq "ND"
      expect(elem_lading_port.text("PostalCode")).to eq "56836"
      expect(elem_lading_port.text("Country")).to eq "US"

      elem_origin_airport = elem_locations.elements.to_a("Location")[1]
      expect(elem_origin_airport.text("LocationType")).to eq "OriginAirportCode"
      expect(elem_origin_airport.text("LocationCode")).to eq "ALF"
      expect(elem_origin_airport.text("LocationCodeType")).to eq "IATA"
      expect(elem_origin_airport.text("Name")).to eq "Airport"
      # This port has no address associated with it.
      expect(elem_origin_airport.text("Address1")).to be_nil
      expect(elem_origin_airport.text("Address2")).to be_nil
      expect(elem_origin_airport.text("Address3")).to be_nil
      expect(elem_origin_airport.text("City")).to be_nil
      expect(elem_origin_airport.text("State")).to be_nil
      expect(elem_origin_airport.text("PostalCode")).to be_nil
      expect(elem_origin_airport.text("Country")).to be_nil

      elem_port_entry = elem_locations.elements.to_a("Location")[2]
      expect(elem_port_entry.text("LocationType")).to eq "PortOfEntry"
      expect(elem_port_entry.text("LocationCode")).to eq "1402"
      expect(elem_port_entry.text("LocationCodeType")).to eq "ScheduleD"
      expect(elem_port_entry.text("Name")).to eq "Entry City"
      # This port's address has no country associated with it.
      expect(elem_port_entry.text("Address1")).to eq "123 Fake Cir"
      expect(elem_port_entry.text("Country")).to be_nil

      elem_port_unlading = elem_locations.elements.to_a("Location")[3]
      expect(elem_port_unlading.text("LocationType")).to eq "PortOfUnlading"
      expect(elem_port_unlading.text("LocationCode")).to eq "1401"
      expect(elem_port_unlading.text("LocationCodeType")).to eq "ScheduleD"
      expect(elem_port_unlading.text("Name")).to eq "Unladingston"
    end

    it "handles assorted nil and missing values" do
      broker = Factory(:company, name: "Vandegrift Forwarding Co.", broker: true)
      broker.addresses.create!(address_type: "Remit To", name: "Vandegrift Inc.", country_id: nil)
      broker.system_identifiers.create!(system: "Filer Code", code: "316")

      # No port records connect to these codes.
      entry = Factory(:entry, lading_port_code: "14001", unlading_port_code: "1401", location_of_goods: "M801",
                              entry_port_code: "1402", origin_airport_code: "ALF")
      bi = entry.broker_invoices.create! bill_to_name: "Bill II"
      bi.broker_invoice_lines.create! charge_code: "0099", charge_amount: BigDecimal("29.95"), charge_description: "Charge-1",
                                      vendor_name: "VendA"

      doc = subject.generate_xml bi

      elem_root = doc.root
      elem_billing_invoice = elem_root.elements.to_a("BillingInvoice")[0]
      expect(elem_billing_invoice).not_to be_nil
      expect(elem_billing_invoice.text("InvoiceDate")).to be_nil
      expect(elem_billing_invoice.text("InvoiceTotal")).to be_nil

      elem_remit_to = elem_billing_invoice.elements.to_a("RemitTo")[0]
      expect(elem_remit_to).not_to be_nil
      expect(elem_remit_to.text("Country")).to be_nil

      expect(elem_billing_invoice.elements.to_a("Consignee").length).to eq 0

      elem_bill_to = elem_billing_invoice.elements.to_a("BillTo")[0]
      expect(elem_bill_to).not_to be_nil
      expect(elem_bill_to.text("Name")).to eq "Bill II"
      expect(elem_bill_to.text("Country")).to be_nil

      expect(elem_billing_invoice.elements.to_a("BillingInvoiceLine").length).to eq 1
      elem_bill_line_1 = elem_billing_invoice.elements.to_a("BillingInvoiceLine")[0]
      expect(elem_bill_line_1.text("VendorName")).to eq "VendA"

      elem_entry = elem_billing_invoice.elements.to_a("Entry")[0]
      expect(elem_entry).not_to be_nil
      expect(elem_entry.text("ModeOfTransportation")).to eq "Other"
      expect(elem_entry.text("CustomsModeOfTransportation")).to be_nil
      expect(elem_entry.text("ExportDate")).to be_nil
      expect(elem_entry.text("ArrivalDate")).to be_nil
      expect(elem_entry.text("ImportDate")).to be_nil
      expect(elem_entry.text("EntryFiledDateTime")).to be_nil
      expect(elem_entry.text("ReleaseDateTime")).to be_nil

      expect(elem_entry.elements.to_a("CountriesOfOrigin").length).to eq 0
      expect(elem_entry.elements.to_a("CountriesOfExport").length).to eq 0

      expect(elem_entry.elements.to_a("Containers").length).to eq 0

      elem_reference_numbers = elem_entry.elements.to_a("ReferenceNumbers")[0]
      expect(elem_reference_numbers).not_to be_nil
      expect(elem_reference_numbers.elements.to_a("ReferenceNumber").length).to eq 0

      elem_locations = elem_entry.elements.to_a("Locations")[0]
      expect(elem_locations).not_to be_nil
      expect(elem_locations.elements.to_a("Location").length).to eq 0
    end

    it "doesn't include bill to or remit to when address info is missing" do
      broker = Factory(:company, name: "Vandegrift Forwarding Co.", broker: true)
      broker.system_identifiers.create!(system: "Filer Code", code: "316")

      entry = Factory(:entry)
      bi = entry.broker_invoices.create!

      doc = subject.generate_xml bi

      elem_root = doc.root
      elem_billing_invoice = elem_root.elements.to_a("BillingInvoice")[0]
      expect(elem_billing_invoice.elements.to_a("RemitTo").length).to eq 0
      expect(elem_billing_invoice.elements.to_a("BillTo").length).to eq 0
    end

    it "doesn't include remit to when broker can't be found" do
      entry = Factory(:entry)
      bi = entry.broker_invoices.create!

      doc = subject.generate_xml bi

      elem_root = doc.root
      elem_billing_invoice = elem_root.elements.to_a("BillingInvoice")[0]
      expect(elem_billing_invoice.elements.to_a("RemitTo").length).to eq 0
    end

    context "ship mode translations" do
      [{code: "10", mode: "Sea"}, {code: "40", mode: "Air"}, {code: "20", mode: "Rail"}, {code: "30", mode: "Truck"}, {code: "150", mode: "Other"}].each do |conv_hash|
        it "converts transport mode code #{conv_hash[:code]} to #{conv_hash[:mode]}" do
          entry = Factory(:entry, transport_mode_code: conv_hash[:code])
          bi = entry.broker_invoices.create!

          doc = subject.generate_xml bi

          elem_root = doc.root
          elem_billing_invoice = elem_root.elements.to_a("BillingInvoice")[0]
          elem_entry = elem_billing_invoice.elements.to_a("Entry")[0]
          expect(elem_entry.text("ModeOfTransportation")).to eq conv_hash[:mode]
          expect(elem_entry.text("CustomsModeOfTransportation")).to eq conv_hash[:code]
        end
      end
    end
  end

  describe "generate_and_send" do
    it "generates and sends a file (test)" do
      allow(stub_master_setup).to receive(:production?).and_return false

      bi = Factory(:broker_invoice, invoice_number: "13579246", customer_number: "KRAANG")

      expect(subject).to receive(:generate_xml).with(bi).and_return REXML::Document.new("<FakeXml><child>A</child></FakeXml>")

      doc = nil
      expect(subject).to receive(:ftp_sync_file) do |file, sync, ftp_creds|
        expect(ftp_creds[:folder]).to eq("to_ecs/billing_invoice_test/KRAANG")
        expect(ftp_creds[:server]).to eq("connect.vfitrack.net")
        expect(ftp_creds[:username]).to eq("www-vfitrack-net")

        doc = REXML::Document.new(file.read)
        sync.ftp_session_id = 357
        expect(file.original_filename).to eq "billing_invoice_13579246_20200324020508.xml"
        file.close!
      end

      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")
      Timecop.freeze(current) do
        subject.generate_and_send bi
      end

      expect(doc.root.name).to eq "FakeXml"

      expect(bi.sync_records.length).to eq 1
      expect(bi.sync_records[0].trading_partner).to eq described_class::SYNC_TRADING_PARTNER
      expect(bi.sync_records[0].sent_at).to eq (current - 1.second)
      expect(bi.sync_records[0].confirmed_at).to eq current
      expect(bi.sync_records[0].ftp_session_id).to eq 357
    end

    it "generates and sends a file (production)" do
      allow(stub_master_setup).to receive(:production?).and_return true

      bi = Factory(:broker_invoice, invoice_number: "13579246", customer_number: "KRAANG")
      expect(subject).to receive(:generate_xml).with(bi).and_return REXML::Document.new("<FakeXml><child>A</child></FakeXml>")

      expect(subject).to receive(:ftp_sync_file) do |file, _sync, ftp_creds|
        # Alternate folder from test.  Everything else behaves the same.
        expect(ftp_creds[:folder]).to eq("to_ecs/billing_invoice/KRAANG")
        file.close!
      end

      subject.generate_and_send bi
    end
  end

end
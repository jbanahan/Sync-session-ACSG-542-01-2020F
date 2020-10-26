describe OpenChain::CustomHandler::Siemens::SiemensCaXmlBillingGenerator do
  let(:co1) do
    co = Factory(:company)
    co.system_identifiers.create! system: "Fenix", code: "807150586RM0001"
    co
  end

  let(:co2) do
    co = Factory(:company)
    co.system_identifiers.create! system: "Fenix", code: "807150586RM0002"
    co
  end

  let(:now) { Time.zone.now }
  let(:date1) { DateTime.new(2020, 3, 15, 9, 30)}
  let(:date2) { DateTime.new(2020, 3, 16, 9, 30)}
  let(:date3) { DateTime.new(2020, 3, 17, 9, 30)}
  let(:date4) { DateTime.new(2020, 3, 18, 9, 30)}
  let!(:sys_date) { SystemDate.create! date_type: "OpenChain::CustomHandler::Siemens::SiemensCaXmlBillingGenerator", start_date: Date.new(2020, 1, 5)}

  let(:ent1) { Factory(:entry, entry_number: "11912345678901", importer: co1, file_logged_date: now, entry_type: "A", importer_tax_id: "807150586RM0001") }
  let(:ent2) { Factory(:entry, importer: co2, file_logged_date: now - 1.day, entry_type: "A", importer_tax_id: "807150586RM0002") }

  describe "run_schedulable" do
    before { ent1; ent2 }

    it "executes" do
      today = now.beginning_of_day
      sys_date.update! start_date: today

      expect_any_instance_of(described_class).to receive(:generate_and_send_entry) do |inst, ent|
        expect(inst.start_date).to eq today
        expect(ent).to eq ent1
      end

      described_class.run_schedulable
    end

    it "raises exception if no SystemDate found" do
      sys_date.destroy
      expect { described_class.run_schedulable }.to raise_error "SystemDate must be set."
    end
  end

  describe "generate_and_send_entry" do
    it "generates and sends a file" do
      allow(stub_master_setup).to receive(:production?).and_return false

      now = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-15 02:05:08")
      expect(subject).to receive(:generate_xml).with(ent1).and_return REXML::Document.new("<FakeXml><child>A</child></FakeXml>")

      doc = nil
      expect(subject).to receive(:ftp_sync_file) do |file, sync|
        doc = REXML::Document.new(file.read)
        sync.ftp_session_id = 357
        expect(file.original_filename).to eq "1005029_CA_B3_119_11912345678901_20200315020508.xml"
        file.close!
      end

      Timecop.freeze(now) { subject.generate_and_send_entry ent1 }

      expect(doc.root.name).to eq "FakeXml"

      ent1.reload
      expect(ent1.sync_records.length).to eq 1
      expect(ent1.sync_records[0].trading_partner).to eq described_class::SYNC_TRADING_PARTNER
      expect(ent1.sync_records[0].sent_at).to eq (now - 1.second)
      expect(ent1.sync_records[0].confirmed_at).to eq now
      expect(ent1.sync_records[0].ftp_session_id).to eq 357
    end
  end

  describe "generate_xml" do
    before do
      ca = Factory(:country, iso_code: "CA")
      ent1.update(import_country: ca, transport_mode_code: "1", cadex_accept_date: date1, broker_reference: "brok ref", total_freight: 305.25,
                  entry_type: "ent type", entry_port_code: "ent port code", ult_consignee_name: "ult consignee name", release_date: date1,
                  entered_value: 25.50, us_exit_port_code: "exit port code", lading_port_code: "lading port code", total_duty: 36.50, customer_name: "cust name",
                  customer_number: "cust num", direct_shipment_date: date2, carrier_code: "carrier code", carrier_name: "carrier name", cargo_control_number: "cargo control",
                  house_bills_of_lading: "ent_hbol1\n ent_hbol2")
      ci = Factory(:commercial_invoice, entry: ent1, currency: "currency", invoice_number: "inv num", master_bills_of_lading: "mbol1\n mbol2",
                                        house_bills_of_lading: "inv_hbol1\n inv_hbol2", mfid: "mid", net_weight: 5.25, exchange_rate: 1.25)
      cil = Factory(:commercial_invoice_line, commercial_invoice: ci, vendor_name: "vend name", po_number: "po num", line_number: 1, customs_line_number: 2,
                                              part_number: "part num", value: 11.25, currency: "GBP", value_foreign: 11.75, country_origin_code: "country origin",
                                              country_export_code: "country export", unit_of_measure: "uom", quantity: 9.25, subheader_number: 3, unit_price: 4.18)
      Factory(:commercial_invoice_tariff, commercial_invoice_line: cil, sima_amount: 2.50, excise_amount: 3.50, gst_amount: 4.50, hts_code: "hts1",
                                          classification_qty_1: 2.25, classification_uom_1: "uom1", tariff_description: "tariff descr", duty_amount: 3.10,
                                          duty_rate_description: "1.10", tariff_provision: "tariff prov", spi_primary: "spi primary", value_for_duty_code: "val for duty code",
                                          sima_code: "sima code", excise_rate_code: "excise rate code", gst_rate_code: "gst rate code",
                                          entered_value: 12.35, gross_weight: 11, special_authority: "special authority")
      Factory(:commercial_invoice_tariff, commercial_invoice_line: cil, sima_amount: 2.75, excise_amount: 3.75, gst_amount: 4.75, duty_amount: 4.10, duty_rate_description: "2.10") # rubocop:disable Layout/LineLength
      pga_line_1 = Factory(:canadian_pga_line, commercial_invoice_line: cil, batch_lot_number: "batch lot num", brand_name: "brand name", commodity_type: "commodity type",
                                               country_of_origin: "coo", exception_processes: "exc process", expiry_date: date3, fda_product_code: "fda product code",
                                               file_name: "file name", gtin: "gtin", importer_contact_email: "imp contact email", importer_contact_name: "imp contact name",
                                               importer_contact_phone: "imp contact phone", intended_use_code: "intended use code", lpco_number: "lpco num",
                                               lpco_type: "lpco type", manufacture_date: date4, model_designation: "model designation", model_label: "model label",
                                               model_number: "model number", product_name: "product name", purpose: "purpose", state_of_origin: "state of origin",
                                               unique_device_identifier: "unique dev id", program_code: "program code", agency_code: "HC")
      Factory(:canadian_pga_line, commercial_invoice_line: cil, batch_lot_number: "batch lot num2", commodity_type: "commodity type", program_code: "program code", agency_code: "HC") # rubocop:disable Layout/LineLength
      Factory(:canadian_pga_line_ingredient, canadian_pga_line: pga_line_1, quality: 0.5, quantity: 5.2, name: "ing name")
      Factory(:canadian_pga_line_ingredient, canadian_pga_line: pga_line_1, quality: 0.75, quantity: 8.2, name: "ing name 2")
    end

    it "generates an XML" do
      doc = subject.generate_xml ent1
      elem_root = doc.root
      expect(elem_root.name).to eq "CA_EV"
      expect(elem_root.namespace('xs')).to eq 'http://www.w3.org/2001/XMLSchema'

      elem_dec = elem_root.elements.to_a("Declaration")[0]
      expect(elem_dec).not_to be_nil

      # Thomson Reuters header
      expect(elem_dec.text("EntryNum")).to eq "11912345678901"
      expect(elem_dec.text("BrokerFileNum")).to eq "brok ref"
      expect(elem_dec.text("BrokerID")).to eq "11912"
      expect(elem_dec.text("BrokerName")).to eq "Vandegrift Inc"
      expect(elem_dec.text("EntryType")).to eq "ent type"
      expect(elem_dec.text("PortOfEntry")).to eq "ent port code"
      expect(elem_dec.text("UltimateConsignee")).to eq "ult consignee name"
      expect(elem_dec.text("ReleaseDate")).to eq "2020-03-15 09:30:00"
      expect(elem_dec.text("TotalEnteredValue")).to eq "25.5"
      expect(elem_dec.text("CurrencyCode")).to eq "currency"
      expect(elem_dec.text("ModeOfTransport")).to eq "1"
      expect(elem_dec.text("PortOfLading")).to eq "lading port code"
      expect(elem_dec.text("TotalDuty")).to eq "36.5"

      # Siemens header
      expect(elem_dec.text("EntryClass")).to eq "ent type"
      expect(elem_dec.text("EntryDate")).to eq "2020-03-15 09:30:00"
      expect(elem_dec.text("ImporterID")).to eq "807150586RM0001"
      expect(elem_dec.text("ImporterName")).to eq "cust name"
      expect(elem_dec.text("OfficeNum")).to eq "ent port code"
      expect(elem_dec.text("GSTRegistrationNum")).to eq "807150586RM0001"
      expect(elem_dec.text("USPortOfExit")).to eq "exit port code"
      expect(elem_dec.text("CAPortOfUnlading")).to eq "ent port code"
      expect(elem_dec.text("Freight")).to eq "305.25"
      expect(elem_dec.text("PaymentCode")).to eq "I"
      expect(elem_dec.text("TotalValueForDuty")).to eq "25.5"
      expect(elem_dec.text("DirectShipmentDate")).to eq "2020-03-16 00:00:00"
      expect(elem_dec.text("CarrierCode")).to eq "carrier code"
      expect(elem_dec.text("CarrierName")).to eq "carrier name"
      expect(elem_dec.text("TotalCustomsDuty")).to eq "7.2"
      expect(elem_dec.text("TotalSIMAAssessment")).to eq "5.25"
      expect(elem_dec.text("TotalExciseTax")).to eq "7.25"
      expect(elem_dec.text("TotalGST")).to eq "9.25"
      expect(elem_dec.text("TotalPayable")).to eq "58.25"

      line_elements = elem_dec.elements.to_a("DeclarationLine")
      expect(line_elements.size).to eq 2
      elem_line_1 = line_elements[0]

      # Thomson Reuters lines
      expect(elem_line_1.text("SupplierName")).to eq "vend name"
      expect(elem_line_1.text("InvoiceNum")).to eq "inv num"
      expect(elem_line_1.text("PurchaseOrderNum")).to eq "po num"
      expect(elem_line_1.text("MasterBillOfLading")).to eq "mbol1"
      expect(elem_line_1.text("HouseBillOfLading")).to eq "inv_hbol1"
      expect(elem_line_1.text("ProductNum")).to eq "part num"
      expect(elem_line_1.text("HsNum")).to eq "hts1"
      expect(elem_line_1.text("GrossWeight")).to eq "11"
      expect(elem_line_1.text("TxnQty")).to eq "2.25"
      expect(elem_line_1.text("LineValue")).to eq "11.25"
      expect(elem_line_1.text("InvoiceCurrency")).to eq "GBP"
      expect(elem_line_1.text("InvoiceQty")).to eq "9.25"
      expect(elem_line_1.text("InvoiceValue")).to eq "11.75"
      expect(elem_line_1.text("TxnQtyUOM")).to eq "uom1"
      expect(elem_line_1.text("WeightUOM")).to eq "KG"

      # Siemens lines
      expect(elem_line_1.text("ClientNumber")).to eq "cust num"
      expect(elem_line_1.text("CCINumber")).to eq "1"
      expect(elem_line_1.text("LineNum")).to eq "2"
      expect(elem_line_1.text("SubHeaderNum")).to eq "3"
      expect(elem_line_1.text("CountryOfOrigin")).to eq "country origin"
      expect(elem_line_1.text("PlaceOfExport")).to eq "country export"
      expect(elem_line_1.text("SupplierID")).to eq "mid"
      expect(elem_line_1.text("SpecialAuthority")).to eq "special authority"
      expect(elem_line_1.text("UnitPrice")).to eq "4.18"
      expect(elem_line_1.text("ValueForCurrencyConversion")).to eq "11.25"
      expect(elem_line_1.text("UnitPriceCurrencyCode")).to eq "GBP"
      expect(elem_line_1.text("CurrencyConversionRate")).to eq "1.25"
      expect(elem_line_1.text("InvoiceQtyUom")).to eq "uom"
      expect(elem_line_1.text("AirwayBillOfLading")).to eq "inv_hbol1"
      expect(elem_line_1.text("Description")).to eq "tariff descr"
      expect(elem_line_1.text("ProductDesc")).to eq "tariff descr"
      expect(elem_line_1.text("NetWeight")).to eq "5.25"
      expect(elem_line_1.text("TariffDuty")).to eq "3.1"
      expect(elem_line_1.text("TariffRate")).to eq "1.1"
      expect(elem_line_1.text("TariffCode")).to eq "tariff prov"
      expect(elem_line_1.text("TariffTreatment")).to eq "spi primary"
      expect(elem_line_1.text("PreferenceCode1")).to eq "spi primary"
      expect(elem_line_1.text("VFDCode")).to eq "val for duty code"
      expect(elem_line_1.text("SIMACode")).to eq "sima code"
      expect(elem_line_1.text("CustomsDutyRate")).to eq "1.1"
      expect(elem_line_1.text("ExciseTaxRate")).to eq "excise rate code"
      expect(elem_line_1.text("GSTRate")).to eq "gst rate code"
      expect(elem_line_1.text("ValueForDuty")).to eq "12.35"
      expect(elem_line_1.text("CustomsDuty")).to eq "3.1"
      expect(elem_line_1.text("SIMAAssessment")).to eq "2.5"
      expect(elem_line_1.text("ExciseTax")).to eq "3.5"
      expect(elem_line_1.text("ValueForTax")).to eq "21.45"
      expect(elem_line_1.text("GST")).to eq "4.5"
      expect(elem_line_1.text("TotalLineTax")).to eq "10.5"
      expect(elem_line_1.text("CustomsInvoiceQty")).to eq "2.25"
      expect(elem_line_1.text("CustomsInvoiceQtyUOM")).to eq "uom1"
      expect(elem_line_1.text("K84AcctDate")).to eq "2020-03-15 09:30:00"
      expect(elem_line_1.text("K84DueDate")).to eq "2020-03-25 00:00:00" # set by Entry callback
      expect(elem_line_1.text("CargoControlNumber")).to eq "cargo control"

      # PGA lines
      elem_pga_agencies = REXML::XPath.match elem_dec, "DeclarationLine/CAPGAHeader/CAPGAAgency"
      # The duplicate second agency appears due to the second tariff, which doesn't occur on CA entries. Ignored from here on.
      expect(elem_pga_agencies.count).to eq 2
      elem_pga_agency = elem_pga_agencies[0]
      elem_pga_details = REXML::XPath.match elem_pga_agency, "CAPGADetails"
      expect(elem_pga_details.count).to eq 3
      expect(elem_pga_agency.text("AgencyCode")).to eq "HC"
      expect(elem_pga_agency.text("ProgramCode")).to eq "program code"
      elem_pga_detail_1 = elem_pga_details[0]

      expect(elem_pga_detail_1.text("BatchLotNumber")).to eq "batch lot num"
      expect(elem_pga_detail_1.text("BrandName")).to eq "brand name"
      expect(elem_pga_detail_1.text("CommodityType")).to eq "commodity type"
      expect(elem_pga_detail_1.text("CountryofOrigin")).to eq "coo"
      expect(elem_pga_detail_1.text("ExceptionProcess")).to eq "exc process"
      expect(elem_pga_detail_1.text("ExpiryDate")).to eq "2020-03-17 09:30:00"
      expect(elem_pga_detail_1.text("FDAProductCode")).to eq "fda product code"
      expect(elem_pga_detail_1.text("File")).to eq "file name"
      expect(elem_pga_detail_1.text("GTINNumber")).to eq "gtin"
      expect(elem_pga_detail_1.text("ImporterContactEmail")).to eq "imp contact email"
      expect(elem_pga_detail_1.text("ImporterContactName")).to eq "imp contact name"
      expect(elem_pga_detail_1.text("ImporterContactTelephoneNumber")).to eq "imp contact phone"

      # PGA ingredients
      expect(elem_pga_detail_1.text("IngredientQuality")).to eq "0.5"
      expect(elem_pga_detail_1.text("IngredientQuantity")).to eq "5.2"
      expect(elem_pga_detail_1.text("Ingredients")).to eq "ing name"

      expect(elem_pga_detail_1.text("IntendedUse")).to eq "intended use code"
      expect(elem_pga_detail_1.text("LPCONumber")).to eq "lpco num"
      expect(elem_pga_detail_1.text("LPCOType")).to eq "lpco type"
      expect(elem_pga_detail_1.text("ManufactureDate")).to eq "2020-03-18 09:30:00"
      expect(elem_pga_detail_1.text("ModelDesignation")).to eq "model designation"
      expect(elem_pga_detail_1.text("ModelName")).to eq "model label"
      expect(elem_pga_detail_1.text("ModelNumber")).to eq "model number"
      expect(elem_pga_detail_1.text("ProductName")).to eq "product name"
      expect(elem_pga_detail_1.text("Purpose")).to eq "purpose"
      expect(elem_pga_detail_1.text("StateofOrigin")).to eq "state of origin"
      expect(elem_pga_detail_1.text("UniqueDeviceIdentifierNumber")).to eq "unique dev id"

      elem_pga_detail_2 = elem_pga_details[1]
      expect(elem_pga_detail_2.text("BatchLotNumber")).to eq "batch lot num"
      # all fields except ingredients repeat
      expect(elem_pga_detail_2.text("IngredientQuality")).to eq "0.75"
      expect(elem_pga_detail_2.text("IngredientQuantity")).to eq "8.2"
      expect(elem_pga_detail_2.text("Ingredients")).to eq "ing name 2"

      elem_pga_detail_3 = elem_pga_details[2]
      expect(elem_pga_detail_3.text("BatchLotNumber")).to eq "batch lot num2"
      # correctly handles missing ingredients
      expect(elem_pga_detail_3.text("IngredientQuality")).to be nil
      expect(elem_pga_detail_3.text("IngredientQuantity")).to be nil
      expect(elem_pga_detail_3.text("Ingredients")).to be nil
    end

    it "generates a CAPGAAgency tag for each agency/program combination" do
      CanadianPgaLine.last.update! program_code: "program code2"

      doc = subject.generate_xml ent1

      elem_root = doc.root
      elem_dec = elem_root.elements.to_a("Declaration")[0]
      expect(elem_dec).not_to be_nil

      line_elements = elem_dec.elements.to_a("DeclarationLine")
      expect(line_elements.size).to eq 2

      # PGA lines
      elem_pga_agencies = REXML::XPath.match elem_dec, "DeclarationLine/CAPGAHeader/CAPGAAgency"
      # The duplicate third and fourth agencies appear due to the second tariff, which doesn't occur on CA entries. Ignored from here on.
      expect(elem_pga_agencies.count).to eq 4
      elem_pga_agency_1, elem_pga_agency_2, = elem_pga_agencies
      elem_pga_details = REXML::XPath.match elem_pga_agency_1, "CAPGADetails"
      expect(elem_pga_details.count).to eq 2
      expect(elem_pga_agency_1.text("ProgramCode")).to eq "program code"
      expect(elem_pga_details[0].text("BatchLotNumber")).to eq "batch lot num"
      expect(elem_pga_details[1].text("BatchLotNumber")).to eq "batch lot num"

      elem_pga_details = REXML::XPath.match elem_pga_agency_2, "CAPGADetails"
      expect(elem_pga_details.count).to eq 1
      expect(elem_pga_agency_2.text("ProgramCode")).to eq "program code2"
      expect(elem_pga_details[0].text("BatchLotNumber")).to eq "batch lot num2"
    end

    it "selects correct data for <Description>" do
      # For any customs_line_number, use the tariff associated with lowest line_number

      ci = CommercialInvoice.first
      ci.commercial_invoice_lines.destroy_all

      cil = Factory(:commercial_invoice_line, commercial_invoice: ci, customs_line_number: 2, line_number: 3)
      Factory(:commercial_invoice_tariff, commercial_invoice_line: cil, tariff_description: "tariff descr")

      cil_2 = Factory(:commercial_invoice_line, commercial_invoice: ci, customs_line_number: 3, line_number: 2)
      Factory(:commercial_invoice_tariff, commercial_invoice_line: cil_2, tariff_description: "tariff descr 2")

      cil_3 = Factory(:commercial_invoice_line, commercial_invoice: ci, customs_line_number: 2, line_number: 1)
      Factory(:commercial_invoice_tariff, commercial_invoice_line: cil_3, tariff_description: "tariff descr 3")

      cil_4 = Factory(:commercial_invoice_line, commercial_invoice: ci, customs_line_number: 2, line_number: 2)
      Factory(:commercial_invoice_tariff, commercial_invoice_line: cil_4, tariff_description: "tariff descr 4")

      doc = subject.generate_xml ent1
      elem_root = doc.root
      elem_dec = elem_root.elements.to_a("Declaration")[0]
      line_elements = elem_dec.elements.to_a("DeclarationLine")

      expect(line_elements.size).to eq 4

      elem_line_1 = line_elements[0]
      expect(elem_line_1.text("LineNum")).to eq "2"
      expect(elem_line_1.text("CCINumber")).to eq "3"
      expect(elem_line_1.text("Description")).to eq "tariff descr 3"

      elem_line_2 = line_elements[1]
      expect(elem_line_2.text("LineNum")).to eq "3"
      expect(elem_line_2.text("CCINumber")).to eq "2"
      expect(elem_line_2.text("Description")).to eq "tariff descr 2"

      elem_line_3 = line_elements[2]
      expect(elem_line_3.text("LineNum")).to eq "2"
      expect(elem_line_3.text("CCINumber")).to eq "1"
      expect(elem_line_3.text("Description")).to eq "tariff descr 3"

      elem_line_4 = line_elements[3]
      expect(elem_line_4.text("LineNum")).to eq "2"
      expect(elem_line_4.text("CCINumber")).to eq "2"
      expect(elem_line_4.text("Description")).to eq "tariff descr 3"
    end

    it "pulls house bill from entry if missing from invoice" do
      ent1.commercial_invoices.first.update! house_bills_of_lading: nil

      doc = subject.generate_xml ent1
      elem_root = doc.root
      elem_dec = elem_root.elements.to_a("Declaration")[0]
      line_elements = elem_dec.elements.to_a("DeclarationLine")
      elem_line_1 = line_elements[0]

      expect(elem_line_1.text("AirwayBillOfLading")).to eq "ent_hbol1"
    end
  end

  describe "entries" do
    before { ent1; ent2 }

    it "returns entries in ordered by file_logged_date" do
      expect(subject.entries).to eq [ent2, ent1]
    end

    it "excludes synced entries" do
      ent1.sync_records.create! trading_partner: "Siemens Billing", sent_at: now, confirmed_at: now + 1.minute
      expect(subject.entries).to eq [ent2]
    end

    it "uses last_exported_from_source to determine whether sync record is out of date" do
      ent1.sync_records.create! trading_partner: "Siemens Billing", sent_at: now, confirmed_at: now + 1.minute
      ent1.update! updated_at: now + 1.hour
      expect(subject.entries).to eq [ent2]

      ent1.update! last_exported_from_source: now + 1.hour
      expect(subject.entries).to eq [ent2, ent1]
    end

    it "excludes entries with other importers" do
      ent1.importer.system_identifiers.first.update! code: "foo"
      expect(subject.entries).to eq [ent2]
    end

    it "excludes entries of type 'F'" do
      ent1.update entry_type: "F"
      expect(subject.entries).to eq [ent2]
    end

    it "excludes entries before specified file_logged_date" do
      ent1.update! file_logged_date: Date.new(2020, 1, 4)
      expect(subject.entries).to eq [ent2]
    end
  end

  describe "ftp_credentials" do
    it "gets test creds" do
      allow(stub_master_setup).to receive(:production?).and_return false
      cred = subject.ftp_credentials
      expect(cred[:folder]).to eq "to_ecs/siemens_hc/b3_test"
    end

    it "gets production creds" do
      allow(stub_master_setup).to receive(:production?).and_return true
      cred = subject.ftp_credentials
      expect(cred[:folder]).to eq "to_ecs/siemens_hc/b3"
    end
  end

end

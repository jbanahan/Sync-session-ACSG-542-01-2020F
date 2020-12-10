describe OpenChain::CustomHandler::Ferguson::FergusonEntryVerificationXmlGenerator do
  describe "generate_xml" do
    it "generates an XML" do
      broker = Factory(:company, name: "Vandegrift Forwarding Co.", broker: true)
      broker.addresses.create!(system_code: "4", name: "Vandegrift Forwarding Co., Inc.", line_1: "180 E Ocean Blvd",
                               line_2: "Suite 270", city: "Long Beach", state: "CA", postal_code: "90802")
      broker.system_identifiers.create!(system: "Filer Code", code: "316")

      tz = ActiveSupport::TimeZone['UTC']
      entry = Factory(:entry, entry_number: "31679758714", entry_type: "01", broker_reference: "ARGH58285",
                              unlading_port_code: "1401", location_of_goods: "M801",
                              first_it_date: Date.new(2020, 5, 11), export_date: Date.new(2020, 3, 29),
                              release_date: tz.parse('2020-04-28 09:25:01'), arrival_date: tz.parse('2020-04-29 08:15:51'),
                              import_date: Date.new(2020, 4, 30), bond_type: "8", bond_surety_number: "457",
                              importer_tax_id: "27267107400", vessel: "EVER LYRIC", ult_consignee_name: "Consignco",
                              recon_flags: "VALUE", pay_type: 7, mpf: BigDecimal("20.14"), hmf: BigDecimal("21.15"),
                              customer_number: "FERENT", customer_name: "Ferguson Inc", export_country_codes: "US\n CA",
                              destination_state: "ND", voyage: "6837kj3e",
                              first_entry_sent_date: tz.parse('2020-05-01 10:35:11'),
                              liquidation_date: tz.parse('2020-05-02 11:45:21'))
      expect(entry).to receive(:total_duty_taxes_fees_amount).and_return BigDecimal("19.91")
      expect(entry).to receive(:post_summary_correction?).and_return true

      inv = entry.commercial_invoices.build(invoice_number: "E1I0954293", exchange_rate: BigDecimal("100.00"),
                                            invoice_date: Date.new(2020, 3, 30))
      inv_line = inv.commercial_invoice_lines.build(customs_line_number: 2, prorated_mpf: BigDecimal("100.67"),
                                                    hmf: BigDecimal("53.33"), cotton_fee: BigDecimal("75.31"),
                                                    related_parties: true, unit_price: BigDecimal("8.55"),
                                                    unit_of_measure: "PCS", freight_amount: BigDecimal("2.61"),
                                                    country_origin_code: "TH", visa_number: "visa6868",
                                                    add_case_number: "add2020", add_duty_amount: BigDecimal("22.33"),
                                                    cvd_case_number: "cvd2121", cvd_duty_amount: BigDecimal("33.22"),
                                                    mid: "383878", vendor_name: "Vendtech", currency: "CAD", line_number: 10)
      inv_line.commercial_invoice_tariffs.build(gross_weight: 13,
                                                hts_code: "9506910030", spi_primary: "SP1", spi_secondary: "SP2",
                                                duty_specific: BigDecimal("73.84"), advalorem_rate: BigDecimal("14.10"),
                                                duty_advalorem: BigDecimal("74.85"), additional_rate: BigDecimal("15.11"),
                                                duty_additional: BigDecimal("75.86"),
                                                tariff_description: "GYM/PLAYGRND EXERC EQUIP;OTHER")
      inv_line.commercial_invoice_tariffs.build(hts_code: "9506910031")

      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")
      doc = nil
      Timecop.freeze(current) do
        doc = subject.generate_xml entry
      end

      elem_root = doc.root
      expect(elem_root.name).to eq "US_EV"
      expect(elem_root.namespace('xsi')).to eq('http://www.w3.org/2001/XMLSchema-instance')
      expect(elem_root.attributes['xsi:noNamespaceSchemaLocation']).to eq('Standard_US_EV_PGA_Import.xsd')

      elem_dec = elem_root.elements.to_a("Declaration")[0]
      expect(elem_dec).not_to be_nil
      expect(elem_dec.text("EntryNum")).to eq "31679758714"
      expect(elem_dec.text("BrokerFileNum")).to eq "ARGH58285"
      expect(elem_dec.text("SummaryDate")).to eq "2020-05-01 10:35:11"
      expect(elem_dec.text("BrokerLocation")).to be_nil
      expect(elem_dec.text("CustomerID")).to eq "FERENT"
      expect(elem_dec.text("CustomerName")).to eq "Ferguson Inc"
      expect(elem_dec.text("TxnDate")).to eq "2020-03-24 02:05:08"
      expect(elem_dec.text("EntryDate")).to eq "2020-04-28 09:25:01"
      expect(elem_dec.text("ExportCountryCode")).to eq "US"
      expect(elem_dec.text("ReconciliationFlag")).to eq "VALUE"
      expect(elem_dec.text("USPortOfUnlading")).to eq "1401"
      expect(elem_dec.text("IORNum")).to eq "27267107400"
      expect(elem_dec.text("BondType")).to eq "8"
      expect(elem_dec.text("IORName")).to eq "Ferguson Inc"
      expect(elem_dec.text("ExportDate")).to eq "2020-03-29 00:00:00"
      expect(elem_dec.text("ImportDate")).to eq "2020-04-30 00:00:00"
      expect(elem_dec.text("ActLiquidationDate")).to eq "2020-05-02 11:45:21"
      expect(elem_dec.text("AssistFlag")).to eq "N"
      expect(elem_dec.text("BondSurety")).to eq "457"
      expect(elem_dec.text("DestinationState")).to eq "ND"
      expect(elem_dec.text("EstimatedDateOfArrival")).to eq "2020-04-29 08:15:51"
      expect(elem_dec.text("TotalHmfAmt")).to eq "21.15"
      expect(elem_dec.text("TotalMpfAmt")).to eq "20.14"
      expect(elem_dec.text("VesselName")).to eq "EVER LYRIC"
      expect(elem_dec.text("VoyageFlightNum")).to eq "6837kj3e"
      expect(elem_dec.text("LocationOfGoods")).to eq "M801"
      expect(elem_dec.text("PaymentTypeIndicator")).to eq "7"
      expect(elem_dec.text("ITDate")).to eq "2020-05-11 00:00:00"
      expect(elem_dec.text("TotalCharges")).to eq "19.91"
      expect(elem_dec.text("ShipDate")).to eq "2020-03-30 00:00:00"
      expect(elem_dec.text("PostSummaryCorrection")).to eq "Y"
      expect(elem_dec.text("FTZNumber")).to be_nil

      line_elements = elem_dec.elements.to_a("DeclarationLine")
      expect(line_elements.size).to eq 2

      elem_line_1 = line_elements[0]
      expect(elem_line_1.text("LineNum")).to eq "2"
      expect(elem_line_1.text("SupplierName")).to eq "Vendtech"
      expect(elem_line_1.text("InvoiceNum")).to eq "E1I0954293"
      expect(elem_line_1.text("HsNum")).to eq "9506910030"
      expect(elem_line_1.text("CountryOfOrigin")).to eq "TH"
      expect(elem_line_1.text("ManufacturerId")).to eq "383878"
      expect(elem_line_1.text("SPICode1")).to eq "SP1"
      expect(elem_line_1.text("SPICode2")).to eq "SP2"
      expect(elem_line_1.text("HsDesc")).to eq "GYM/PLAYGRND EXERC EQUIP;OTHER"
      expect(elem_line_1.text("AdValoremDuty")).to eq "74.85"
      expect(elem_line_1.text("MpfAmt")).to eq "100.67"
      expect(elem_line_1.text("HmfAmt")).to eq "53.33"
      expect(elem_line_1.text("CottonFee")).to eq "75.31"
      expect(elem_line_1.text("AdValoremRate")).to eq "14.1"
      expect(elem_line_1.text("ADDFlag")).to eq "Y"
      expect(elem_line_1.text("ADCaseNum")).to eq "add2020"
      expect(elem_line_1.text("ADDuty")).to eq "22.33"
      expect(elem_line_1.text("CVDFlag")).to eq "Y"
      expect(elem_line_1.text("CVCaseNum")).to eq "cvd2121"
      expect(elem_line_1.text("CVDuty")).to eq "33.22"
      expect(elem_line_1.text("InvoiceQtyUOM")).to eq "PCS"
      expect(elem_line_1.text("RelatedPartyFlag")).to eq "Y"
      expect(elem_line_1.text("SpecificDuty")).to eq "73.84"
      expect(elem_line_1.text("ReferenceNum")).to eq "1"
      expect(elem_line_1.text("VisaNum")).to eq "visa6868"
      expect(elem_line_1.text("FreightCharge")).to eq "2.61"
      expect(elem_line_1.text("FreightChargeCurrencyCode")).to eq "CAD"
      expect(elem_line_1.text("InvoiceExchangeRate")).to eq "100"
      expect(elem_line_1.text("InvoiceLineNum")).to eq "10"
      expect(elem_line_1.text("LineGrossWeight")).to eq "13"
      expect(elem_line_1.text("UnitPrice")).to eq "8.55"
      expect(elem_line_1.text("AddlDuty")).to eq "75.86"
      expect(elem_line_1.text("AddlDutyRate")).to eq "15.11"

      elem_line_2 = line_elements[1]
      expect(elem_line_1.text("LineNum")).to eq "2"
      expect(elem_line_2.text("InvoiceNum")).to eq "E1I0954293"
      expect(elem_line_2.text("HsNum")).to eq "9506910031"
      expect(elem_line_2.text("ReferenceNum")).to eq "2"
      expect(elem_line_2.text("InvoiceLineNum")).to eq "10"
    end

    it "includes FTZNumber value when entry type is '06'" do
      entry = Factory(:entry, entry_number: "31679758714", entry_type: "06", vessel: "SS Minnow")

      doc = subject.generate_xml entry

      elem_dec = doc.root.elements.to_a("Declaration")[0]
      expect(elem_dec.text("FTZNumber")).to eq "SS Minnow"
    end

    it "shows N flag values when conditions not met" do
      entry = Factory(:entry, entry_number: "31679758714", master_bills_of_lading: "A\n B")
      expect(entry).to receive(:post_summary_correction?).and_return false

      inv = entry.commercial_invoices.build
      inv_line = inv.commercial_invoice_lines.build(related_parties: false, add_case_number: " ", cvd_case_number: " ")
      inv_line.commercial_invoice_tariffs.build

      doc = subject.generate_xml entry

      elem_dec = doc.root.elements.to_a("Declaration")[0]
      expect(elem_dec.text("PostSummaryCorrection")).to eq "N"

      line_elements = elem_dec.elements.to_a("DeclarationLine")
      elem_line = line_elements[0]
      expect(elem_line.text("ADDFlag")).to eq "N"
      expect(elem_line.text("CVDFlag")).to eq "N"
      expect(elem_line.text("RelatedPartyFlag")).to eq "N"
    end

    context "AssistFlag" do
      it "shows 'Y' value when one invoice line has an add to make amount value" do
        entry = Factory(:entry)
        inv = entry.commercial_invoices.build
        inv_line_1 = inv.commercial_invoice_lines.build(add_to_make_amount: BigDecimal(0))
        inv_line_1.commercial_invoice_tariffs.build
        inv_line_2 = inv.commercial_invoice_lines.build(add_to_make_amount: BigDecimal(1))
        inv_line_2.commercial_invoice_tariffs.build

        doc = subject.generate_xml entry

        elem_dec = doc.root.elements.to_a("Declaration")[0]
        expect(elem_dec.text("AssistFlag")).to eq "Y"
      end

      it "shows 'Y' value when one invoice line has an other amount value" do
        entry = Factory(:entry)
        inv = entry.commercial_invoices.build
        inv_line_1 = inv.commercial_invoice_lines.build(other_amount: BigDecimal(0))
        inv_line_1.commercial_invoice_tariffs.build
        inv_line_2 = inv.commercial_invoice_lines.build(other_amount: BigDecimal(1))
        inv_line_2.commercial_invoice_tariffs.build

        doc = subject.generate_xml entry

        elem_dec = doc.root.elements.to_a("Declaration")[0]
        expect(elem_dec.text("AssistFlag")).to eq "Y"
      end

      it "shows 'N' value when no invoice lines have an add to make amount or other amount value" do
        entry = Factory(:entry)
        inv = entry.commercial_invoices.build
        inv_line_1 = inv.commercial_invoice_lines.build(add_to_make_amount: BigDecimal(0), other_amount: BigDecimal(0))
        inv_line_1.commercial_invoice_tariffs.build
        inv_line_2 = inv.commercial_invoice_lines.build(add_to_make_amount: nil, other_amount: nil)
        inv_line_2.commercial_invoice_tariffs.build

        doc = subject.generate_xml entry

        elem_dec = doc.root.elements.to_a("Declaration")[0]
        expect(elem_dec.text("AssistFlag")).to eq "N"
      end
    end
  end

  describe "generate_and_send" do
    it "generates and sends a file" do
      allow(stub_master_setup).to receive(:production?).and_return false

      entry = Factory(:entry, entry_number: "13579246")
      expect(entry).to receive(:post_summary_correction?).and_return(false)

      expect(subject).to receive(:generate_xml).with(entry).and_return REXML::Document.new("<FakeXml><child>A</child></FakeXml>")

      doc = nil
      expect(subject).to receive(:ftp_sync_file) do |file, sync|
        doc = REXML::Document.new(file.read)
        sync.ftp_session_id = 357
        expect(file.original_filename).to eq "1180119_7501_316_13579246_20200324020508.xml"
        file.close!
      end

      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")
      Timecop.freeze(current) do
        subject.generate_and_send entry
      end

      expect(doc.root.name).to eq "FakeXml"

      expect(entry.sync_records.length).to eq 1
      expect(entry.sync_records[0].trading_partner).to eq described_class::SYNC_TRADING_PARTNER
      expect(entry.sync_records[0].sent_at).to eq (current - 1.second)
      expect(entry.sync_records[0].confirmed_at).to eq current
      expect(entry.sync_records[0].ftp_session_id).to eq 357
    end

    it "generates file with alternate prefix in production environment" do
      allow(stub_master_setup).to receive(:production?).and_return true

      entry = Factory(:entry, entry_number: "13579246")
      expect(entry).to receive(:post_summary_correction?).and_return(false)

      expect(subject).to receive(:generate_xml).with(entry).and_return REXML::Document.new("<FakeXml><child>A</child></FakeXml>")

      expect(subject).to receive(:ftp_sync_file) do |file, _sync|
        expect(file.original_filename).to eq "118011_7501_316_13579246_20200324020508.xml"
        file.close!
      end

      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")
      Timecop.freeze(current) do
        subject.generate_and_send entry
      end
    end

    it "generates post summary correction file" do
      allow(stub_master_setup).to receive(:production?).and_return false

      entry = Factory(:entry, entry_number: "13579246")
      expect(entry).to receive(:post_summary_correction?).and_return(true)

      expect(subject).to receive(:generate_xml).with(entry).and_return REXML::Document.new("<FakeXml><child>A</child></FakeXml>")

      expect(subject).to receive(:ftp_sync_file) do |file, _sync|
        expect(file.original_filename).to eq "1180119_PSC_316_13579246_20200324020508.xml"
        file.close!
      end

      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")
      Timecop.freeze(current) do
        subject.generate_and_send entry
      end
    end
  end

  describe "run_schedulable" do
    subject { described_class }

    it "calls generate and send method for each matching entry" do
      entry_no_sync = Factory(:entry, customer_number: "FERENT", last_exported_from_source: Date.new(2020, 4, 14),
                                      release_date: Date.new(2020, 4, 15), entry_type: nil)

      entry_old_sync = Factory(:entry, customer_number: "HPPRO", last_exported_from_source: Date.new(2020, 4, 14),
                                       release_date: Date.new(2020, 4, 15), entry_type: "X")
      entry_old_sync.sync_records.create!(trading_partner: described_class::SYNC_TRADING_PARTNER, sent_at: Date.new(2020, 4, 13))

      # This should be excluded because it has a sync record with a sent at date later than the entry's last exported from source.
      entry_new_sync = Factory(:entry, customer_number: "FERENT", last_exported_from_source: Date.new(2020, 4, 14),
                                       release_date: Date.new(2020, 4, 15), entry_type: "X")
      entry_new_sync.sync_records.create!(trading_partner: described_class::SYNC_TRADING_PARTNER, sent_at: Date.new(2020, 4, 15))

      # This should be excluded because it belongs to a different importer.
      entry_not_ferg = Factory(:entry, customer_number: "FOR RENT", last_exported_from_source: Date.new(2020, 4, 14),
                                       release_date: Date.new(2020, 4, 15), entry_type: "X")

      # This should be included because it is type 06 and has a first_entry_sent_date value.
      entry_type_06_present_first_entry_sent_date = Factory(:entry, customer_number: "FERENT",
                                                                    last_exported_from_source: Date.new(2020, 4, 14),
                                                                    release_date: Date.new(2020, 4, 15), entry_type: "06",
                                                                    first_entry_sent_date: Date.new(2020, 4, 10))

      # This should be excluded because it is type 06 and does not have a first_entry_sent_date value.
      entry_type_06_missing_first_entry_sent_date = Factory(:entry, customer_number: "FERENT", last_exported_from_source:
                                                            Date.new(2020, 4, 14), release_date: Date.new(2020, 4, 15),
                                                                    entry_type: "06", first_entry_sent_date: nil)

      # This should be excluded because it has no release date yet.
      entry_no_release_date = Factory(:entry, customer_number: "FERENT", last_exported_from_source: Date.new(2020, 4, 14), final_statement_date: nil, entry_type: "X")

      expect_any_instance_of(subject).to receive(:generate_and_send).with(entry_old_sync)
      expect_any_instance_of(subject).to receive(:generate_and_send).with(entry_no_sync)
      expect_any_instance_of(subject).to receive(:generate_and_send).with(entry_type_06_present_first_entry_sent_date)
      expect_any_instance_of(subject).not_to receive(:generate_and_send).with(entry_new_sync)
      expect_any_instance_of(subject).not_to receive(:generate_and_send).with(entry_not_ferg)
      expect_any_instance_of(subject).not_to receive(:generate_and_send).with(entry_type_06_missing_first_entry_sent_date)
      expect_any_instance_of(subject).not_to receive(:generate_and_send).with(entry_no_release_date)

      subject.run_schedulable
    end
  end

  describe "ftp_credentials" do
    it "gets test creds" do
      allow(stub_master_setup).to receive(:production?).and_return false
      cred = subject.ftp_credentials
      expect(cred[:folder]).to eq "to_ecs/ferguson_entry_verification_test"
    end

    it "gets production creds" do
      allow(stub_master_setup).to receive(:production?).and_return true
      cred = subject.ftp_credentials
      expect(cred[:folder]).to eq "to_ecs/ferguson_entry_verification"
    end
  end

end
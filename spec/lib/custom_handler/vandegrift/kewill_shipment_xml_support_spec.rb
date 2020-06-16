describe OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport do
  subject {
    Class.new {
      include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport
    }.new
  }

  describe "generate_entry_xml" do
    context "with entry xml" do

      let (:container) {
        c = described_class::CiLoadContainer.new "CONT_NO", "SEAL_NO"
        c.size = "20FT"
        c.description = "DESC"
        c.pieces = BigDecimal("30")
        c.pieces_uom = "CUOM"
        c.weight_kg = BigDecimal("30")
        c.container_type = "CTYPE"

        c
      }

      let (:bill_of_lading) {
        described_class::CiLoadBillsOfLading.new "SCAC1234567890", "HBOL9876543210", "SUBH5678901234", "SSUB5432109876", BigDecimal(10), "BUOM"
      }

      let (:dates) {
        [
          described_class::CiLoadEntryDate.new(:est_arrival_date, Date.new(2018, 3, 1)),
          described_class::CiLoadEntryDate.new(:export_date, Date.new(2018, 2, 1)),
          described_class::CiLoadEntryDate.new(:arrival_date, Date.new(2020, 2, 1)),
        ]
      }

      let (:entry) {
        e = described_class::CiLoadEntry.new
        e.file_number = "12345"
        e.customer = "CUST"
        e.customer_reference = "REF"
        e.vessel = "VESSEL"
        e.voyage = "VOYAGE"
        e.carrier = "CARR"
        e.customs_ship_mode = 10
        e.lading_port = "LPORT"
        e.unlading_port = "PORT"
        e.entry_port = "EPORT"
        e.pieces = 5
        e.pieces_uom = "SUOM"
        e.goods_description = "DESC"
        e.weight_kg = BigDecimal("20")
        e.consignee_code = "CONSIGNEE"
        e.ultimate_consignee_code = "ULTCONS"
        e.country_of_origin = "OR"
        e.country_of_export = "EX"
        e.bond_type = "B"
        e.destination_state = "XX"
        e.location_of_goods = "GOODS LOCATION"
        e.entry_type = "1"
        e.entry_filer_code = "316"
        e.entry_number = "31612345"
        e.total_value_us = BigDecimal("12.50")
        e.firms_code = "FIRM"
        e.recon_value_flag = true
        e.charges = BigDecimal("123.456")

        e.dates = dates
        e.containers = [container]
        e.bills_of_lading = [bill_of_lading]

        e
      }

      it "builds entry xml" do
        now = Time.zone.now
        doc = nil
        Timecop.freeze(now) { doc = subject.generate_entry_xml entry }

        # We're only concerned here with the data under ediShipment, the rest is tested elsewhere
        s = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment"
        expect(s).not_to be_nil

        expect(s.text "fileNo").to eq "12345"
        expect(s.text "custNo").to eq "CUST"
        expect(s.text "entryType").to eq "1"
        expect(s.text "entryFilerCode").to eq "316"
        expect(s.text "entryNo").to eq "31612345"
        expect(s.text "valueUsAmt").to eq "12.50"
        expect(s.text "custRef").to eq "REF"
        expect(s.text "vesselAirlineName").to eq "VESSEL"
        expect(s.text "voyageFlightNo").to eq "VOYAGE"
        expect(s.text "scac").to eq "SCAC"
        expect(s.text "carrier").to eq "CARR"
        expect(s.text "mot").to eq "10"
        expect(s.text "portLading").to eq "LPORT"
        expect(s.text "distPort").to eq "PORT"
        expect(s.text "distPortEntry").to eq "EPOR"
        expect(s.text "dateEstArrival").to eq "20180301"
        expect(s.text "dateArrival").to eq "20200201"
        expect(s.text "masterBill").to eq "1234567890"
        expect(s.text "houseBill").to eq "9876543210"
        expect(s.text "pieceCount").to eq "5"
        expect(s.text "uom").to eq "SUOM"
        expect(s.text "descOfGoods").to eq "DESC"
        expect(s.text "weightGross").to eq "20"
        expect(s.text "uomWeight").to eq "KG"
        expect(s.text "consignee").to eq "CONSIGNEE"
        expect(s.text "ultimateConsignee").to eq "ULTCONS"
        expect(s.text "countryOrigin").to eq "OR"
        expect(s.text "countryExport").to eq "EX"
        expect(s.text "bondType").to eq "B"
        expect(s.text "destinationState").to eq "XX"
        expect(s.text "firmsCode").to eq "FIRM"
        expect(s.text "mot").to eq "10"
        expect(s.text "reconValue").to eq "Y"
        expect(s.text "chargesAmt").to eq "123.46"
        # It should add this by default since edi_received_date wasn't used
        expect(s.text "dateReceived").to eq now.in_time_zone("America/New_York").strftime("%Y%m%d")

        expect(s.text "EdiShipmentHeaderAux/masterBill").to eq "1234567890"
        expect(s.text "EdiShipmentHeaderAux/houseBill").to eq "9876543210"
        expect(s.text "EdiShipmentHeaderAux/subBill").to eq "5678901234"
        expect(s.text "EdiShipmentHeaderAux/subSubBill").to eq "5432109876"
        expect(s.text "EdiShipmentHeaderAux/locationOfGoods").to eq "GOODS LOCATION"


        expect(s.text "EdiShipmentIdList/EdiShipmentId/seqNo").to eq "1"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/masterBill").to eq "1234567890"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/houseBill").to eq "9876543210"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/subBill").to eq "5678901234"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/subSubBill").to eq "5432109876"

        expect(s.text "EdiShipmentIdList/EdiShipmentId/scac").to eq "SCAC"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/scacHouse").to eq "HBOL"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/masterBillAddl").to eq "1234567890"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/houseBillAddl").to eq "9876543210"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/subBillAddl").to eq "5678901234"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/subSubBillAddl").to eq "5432109876"

        expect(s.text "EdiShipmentIdList/EdiShipmentId/qty").to eq "10"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/uom").to eq "BUOM"

        expect(s.text "EdiShipmentDatesList/EdiShipmentDates/masterBill").to eq "1234567890"
        expect(s.text "EdiShipmentDatesList/EdiShipmentDates/houseBill").to eq "9876543210"
        expect(s.text "EdiShipmentDatesList/EdiShipmentDates/tracingDateNo").to eq "1"
        expect(s.text "EdiShipmentDatesList/EdiShipmentDates/dateTracingShipment").to eq "20180201"

        expect(s.text "EdiContainersList/EdiContainers/masterBill").to eq "1234567890"
        expect(s.text "EdiContainersList/EdiContainers/houseBill").to eq "9876543210"
        expect(s.text "EdiContainersList/EdiContainers/noContainer").to eq "CONT_NO"
        expect(s.text "EdiContainersList/EdiContainers/sealNo").to eq "SEAL_NO"
        expect(s.text "EdiContainersList/EdiContainers/custNo").to eq "CUST"
        expect(s.text "EdiContainersList/EdiContainers/contSize").to eq "20FT"
        expect(s.text "EdiContainersList/EdiContainers/descContent1").to eq "DESC"
        expect(s.text "EdiContainersList/EdiContainers/pieces").to eq "30"
        expect(s.text "EdiContainersList/EdiContainers/uom").to eq "CUOM"
        expect(s.text "EdiContainersList/EdiContainers/weight").to eq "30"
        expect(s.text "EdiContainersList/EdiContainers/uomWeight").to eq "KG"
        expect(s.text "EdiContainersList/EdiContainers/containerType").to eq "CTYPE"
      end

      it "allows bills over 12 digits, truncating to 12" do
        bill_of_lading.master_bill = "MBOL123456789012345"
        bill_of_lading.house_bill = "HBOL987654321098765"
        bill_of_lading.sub_bill = "SUBB123456789012345"
        bill_of_lading.sub_sub_bill = "SSUB987654321098765"
        doc = subject.generate_entry_xml entry

        # We're only concerned here with the data under ediShipment, the rest is tested elsewhere
        s = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment"
        expect(s).not_to be_nil

        expect(s.text "EdiShipmentIdList/EdiShipmentId/scac").to eq "MBOL"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/masterBillAddl").to eq "123456789012"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/scacHouse").to eq "HBOL"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/houseBillAddl").to eq "987654321098"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/subBillAddl").to eq "123456789012"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/subSubBillAddl").to eq "987654321098"
      end

      it "does not add default receivedDate if one is already present" do
        entry.dates << described_class::CiLoadEntryDate.new(:edi_received_date, Date.new(2020, 3, 24))
        doc = subject.generate_entry_xml entry
        s = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment"
        expect(s).not_to be_nil
        expect(s.text "dateReceived").to eq "20200324"
      end

      it "defaults UOM to CTNS" do
        entry.pieces_uom = nil
        entry.containers.first.pieces_uom = nil

        doc = subject.generate_entry_xml entry
        s = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment"
        expect(s).not_to be_nil
        expect(s.text "uom").to eq "CTNS"
        expect(s.text "EdiContainersList/EdiContainers/uom").to eq "CTNS"
      end
    end

    context "with commercial invoice data" do
      let(:entry_data) {
        e = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new '597549', 'SALOMON', []
        i = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new '15MSA10', Date.new(2015, 11, 1), []
        i.non_dutiable_amount = BigDecimal("5")
        i.add_to_make_amount = BigDecimal("25")
        i.charges = BigDecimal("99999999999.989")
        i.customer_reference = "CUSTREF"
        i.net_weight = BigDecimal("9999999.999989")
        i.net_weight_uom = "KG"
        i.gross_weight_kg = BigDecimal("99.99")

        e.invoices << i
        l = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
        l.part_number = "PART"
        l.country_of_origin = "PH"
        l.country_of_export = "CE"
        l.gross_weight = BigDecimal("78")
        l.pieces = BigDecimal("93")
        l.hts = "4202.92.3031"
        l.foreign_value = BigDecimal("3177.86")
        l.quantity_1 = BigDecimal("93")
        l.uom_1 = "QT1"
        l.quantity_2 = BigDecimal("52")
        l.uom_2 = "QT2"
        l.quantity_3 = BigDecimal("75")
        l.uom_3 = "QT3"
        l.po_number = "5301195481"
        l.first_sale = BigDecimal("218497.20")
        l.department = 1.0
        l.add_to_make_amount = BigDecimal("15")
        l.non_dutiable_amount = BigDecimal("20")
        l.cotton_fee_flag = ""
        l.mid = "PHMOUINS2106BAT"
        l.cartons = BigDecimal("10")
        l.spi = "JO"
        l.spi2 = "A+"
        l.unit_price = BigDecimal("15.50")
        l.line_number = "123"
        l.country_of_export = "CE"
        l.charges = BigDecimal("20.25")
        l.related_parties = true
        l.ftz_quantity = BigDecimal("25.50")
        l.ftz_zone_status = "P"
        l.ftz_priv_status_date = "20190315"
        l.description = "Description"
        l.container_number = "ContainerNo"
        l.category_number = "123"
        l.exported_date = Date.new(2020, 2, 13)
        l.visa_date = Date.new(2020, 2, 7)
        l.visa_number = "12345"
        l.lading_port = 12345
        l.textile_category_code = "123"
        l.ruling_type = 'B'
        l.ruling_number = "123"
        l.net_weight = BigDecimal("9999999.999989")
        l.net_weight_uom = "KG"

        i.invoice_lines << l

        l = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
        l.part_number = "PART2"
        l.country_of_origin = "PH"
        l.gross_weight = BigDecimal("78")
        l.pieces = BigDecimal("93")
        l.hts = "4202.92.3031"
        l.foreign_value = BigDecimal("3177.86")
        l.quantity_1 = BigDecimal("93")
        l.quantity_2 = BigDecimal("52")
        l.po_number = "5301195481"
        l.first_sale = BigDecimal("218497.20")
        l.department = 1.0
        l.add_to_make_amount = BigDecimal("15")
        l.non_dutiable_amount = BigDecimal("20")
        l.cotton_fee_flag = ""
        l.mid = "PHMOUINS2106BAT"
        l.cartons = BigDecimal("20")
        l.spi = "JO"
        l.unit_price = BigDecimal("15.50")
        l.container_number = "ContainerNo"
        l.net_weight = BigDecimal("1")

        i.invoice_lines << l

        e
      }

      let (:buyer) {
        c = with_customs_management_id(Factory(:importer), "BUY")
        c.addresses.create! system_code: "1", name: "Buyer", line_1: "Addr1", line_2: "Addr2", city: "City", state: "ST", country: Factory(:country, iso_code: "US"), postal_code: "00000"

        c
      }

      let (:mid) {
        ManufacturerId.create! mid: "MID", name: "Manufacturer", address_1: "Addr1", address_2: "Addr2", city: "City", country: "CO", postal_code: "00000", active: true
      }

      let (:invoice_party) {
        p = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadParty.new
        p.qualifier = "PY"
        p.name = "PARTY"
        p.address_1 = "ADDR 1"
        p.address_2 = "ADDR 2"
        p.address_3 = "ADDR 3"
        p.city = "CITY"
        p.country_subentity = "STATE"
        p.country = "CO"
        p.customer_number = "CUSTNO"
        p.zip = "12345"
        p.mid = "COMANUFACTURER"

        p
      }

      it "generates entry data to given xml element" do
        buyer
        mid
        entry_data.invoices.first.invoice_lines.first.buyer_customer_number = "BUY"
        entry_data.invoices.first.invoice_lines.first.seller_mid = "MID"

        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList"
        expect(t).not_to be_nil


        # Make sure entry / shipment information is not in the xml
        expect(t.text "EdiShipmentHeader/custNo").to be_nil

        t = REXML::XPath.first t, "EdiInvoiceHeader"
        expect(t.text "manufacturerId").to eq "597549"
        expect(t.text "commInvNo").to eq "15MSA10"
        expect(t.text "dateInvoice").to eq "20151101"
        expect(t.text "custNo").to eq "SALOMON"
        expect(t.text "nonDutiableAmt").to eq "500"
        expect(t.text "addToMakeAmt").to eq "2500"
        expect(t.text "currency").to eq "USD"
        expect(t.text "exchangeRate").to eq "1000000"
        expect(t.text "qty").to eq "30"
        expect(t.text "uom").to eq "CTNS"
        expect(t.text "chargesAmt").to eq "99999999999.99"
        expect(t.text "netWeightAmt").to eq "9999999.99999"
        expect(t.text "netWtUom").to eq "KG"
        expect(t.text "custRef").to eq "CUSTREF"
        expect(t.text "weightGross").to eq "100"

        l = REXML::XPath.first t, "EdiInvoiceLinesList/EdiInvoiceLines"
        expect(l).not_to be_nil

        expect(l.text "manufacturerId").to eq "597549"
        expect(l.text "commInvNo").to eq "15MSA10"
        expect(l.text "dateInvoice").to eq "20151101"
        expect(l.text "custNo").to eq "SALOMON"
        expect(l.text "commInvLineNo").to eq '10'
        expect(l.text "partNo").to eq "PART"
        expect(l.text "countryOrigin").to eq "PH"
        expect(l.text "countryExport").to eq "CE"
        expect(l.text "weightGross").to eq "78"
        expect(l.text "kilosPounds").to eq "KG"
        expect(l.text "qtyCommercial").to eq "93000"
        expect(l.text "uomCommercial").to eq "PCS"
        expect(l.text "uomVolume").to eq "M3"
        expect(l.text "unitPrice").to eq "15500"
        expect(l.text "tariffNo").to eq "4202923031"
        expect(l.text "valueForeign").to eq "317786"
        expect(l.text "qty1Class").to eq "9300"
        expect(l.text "uom1Class").to eq "QT1"
        expect(l.text "qty2Class").to eq "5200"
        expect(l.text "uom2Class").to eq "QT2"
        expect(l.text "qty3Class").to eq "7500"
        expect(l.text "uom3Class").to eq "QT3"
        expect(l.text "purchaseOrderNo").to eq "5301195481"
        expect(l.text "custRef").to eq "5301195481"
        expect(l.text "contract").to eq "218497.2"
        expect(l.text "department").to eq "1"
        expect(l.text "spiPrimary").to eq "JO"
        expect(l.text "nonDutiableAmt").to eq "2000"
        expect(l.text "addToMakeAmt").to eq "1500"
        expect(l.text "exemptionCertificate").to be_nil
        expect(l.text "manufacturerId2").to eq "PHMOUINS2106BAT"
        expect(l.text "cartons").to eq "10"
        expect(l.text "detailLineNo").to eq "123"
        expect(l.text "countryExport").to eq "CE"
        expect(l.text "chargesAmt").to eq "20.25"
        expect(l.text "relatedParties").to eq "Y"
        expect(l.text "ftzQuantity").to eq "26"
        expect(l.text "ftzZoneStatus").to eq "P"
        expect(l.text "ftzPrivStatusDate").to eq "20190315"
        expect(l.text "descr").to eq "Description"
        expect(l.text "noContainer").to eq "ContainerNo"
        expect(l.text "categoryNo").to eq "123"
        expect(l.text "dateExport").to eq "20200213"
        expect(l.text "visaDate").to eq "20200207"
        expect(l.text "portLading").to eq "12345"
        expect(l.text "categoryNo").to eq "123"
        expect(l.text "rulingType").to eq "B"
        expect(l.text "rulingNo").to eq "123"
        expect(l.text "netWeightAmt").to eq "9999999.99999"
        expect(l.text "netWtUom").to eq "KG"

        parties = REXML::XPath.first l, "EdiInvoicePartyList"
        expect(parties).not_to be_nil
        buyer = REXML::XPath.first l, "EdiInvoicePartyList/EdiInvoiceParty[partiesQualifier = 'BY']"
        expect(buyer).not_to be_nil
        expect(buyer.text "commInvNo").to eq "15MSA10"
        expect(buyer.text "commInvLineNo").to eq "10"
        expect(buyer.text "dateInvoice").to eq "20151101"
        expect(buyer.text "manufacturerId").to eq "597549"
        expect(buyer.text "address1").to eq "Addr1"
        expect(buyer.text "address2").to eq "Addr2"
        expect(buyer.text "city").to eq "City"
        expect(buyer.text "country").to eq "US"
        expect(buyer.text "countrySubentity").to eq "ST"
        expect(buyer.text "custNo").to eq "BUY"
        expect(buyer.text "name").to eq "Buyer"
        expect(buyer.text "zip").to eq "00000"

        seller = REXML::XPath.first l, "EdiInvoicePartyList/EdiInvoiceParty[partiesQualifier = 'SE']"
        expect(seller).not_to be_nil
        expect(seller.text "commInvNo").to eq "15MSA10"
        expect(seller.text "commInvLineNo").to eq "10"
        expect(seller.text "dateInvoice").to eq "20151101"
        expect(seller.text "manufacturerId").to eq "597549"
        expect(seller.text "address1").to eq "Addr1"
        expect(seller.text "address2").to eq "Addr2"
        expect(seller.text "city").to eq "City"
        expect(seller.text "country").to eq "CO"
        expect(seller.text "name").to eq "Manufacturer"
        expect(seller.text "zip").to eq "00000"
      end

      it "allows for manually adding distinct parties" do
        entry_data.invoices.first.invoice_lines.first.parties = [invoice_party]

        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines"
        expect(t).not_to be_nil

        p = REXML::XPath.first t, "EdiInvoicePartyList/EdiInvoiceParty[partiesQualifier = 'PY']"
        expect(p).not_to be_nil
        expect(p.text "commInvNo").to eq "15MSA10"
        expect(p.text "commInvLineNo").to eq "10"
        expect(p.text "dateInvoice").to eq "20151101"
        expect(p.text "manufacturerId").to eq "597549"
        expect(p.text "name").to eq "PARTY"
        expect(p.text "address1").to eq "ADDR 1"
        expect(p.text "address2").to eq "ADDR 2"
        expect(p.text "address3").to eq "ADDR 3"
        expect(p.text "city").to eq "CITY"
        expect(p.text "country").to eq "CO"
        expect(p.text "countrySubentity").to eq "STATE"
        expect(p.text "zip").to eq "12345"
        expect(p.text "custNo").to eq "CUSTNO"
        expect(p.text "partyMidCd").to eq "COMANUFACTURER"
      end

      it "pulls MID code from MF party, skipping the party data " do
        invoice_party.qualifier = "MF"
        invoice_line = entry_data.invoices.first.invoice_lines.first
        invoice_line.parties = [invoice_party]
        invoice_line.mid = nil

        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines"
        expect(t).not_to be_nil

        expect(t.text "manufacturerId2").to eq "COMANUFACTURER"
        p = REXML::XPath.first t, "EdiInvoicePartyList"
        expect(p).to be_nil
      end

      it "generates 999999999 as cert value when cotton fee flag is 1" do
        mid
        d = entry_data
        d.invoices.first.invoice_lines.first.cotton_fee_flag = "1"
        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines"
        expect(t).not_to be_nil
        expect(t.text "exemptionCertificate").to eq "999999999"
      end

      it "generates 999999999 as cert value when cotton fee flag is N" do
        mid
        d = entry_data
        d.invoices.first.invoice_lines.first.cotton_fee_flag = "N"
        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines"
        expect(t).not_to be_nil
        expect(t.text "exemptionCertificate").to eq "999999999"
      end

      it "uses ascii encoding for string data w/ ? as a replacement char" do
        d = entry_data
        d.invoices.first.invoice_number = "Test ¶"

        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader"
        expect(t).not_to be_nil
        expect(t.text "commInvNo").to eq "Test ?"
      end

      it "allows using alternate addresses for buyers" do
        buyer
        mid
        entry_data.invoices.first.invoice_lines.first.buyer_customer_number = "BUY"
        entry_data.invoices.first.invoice_lines.first.seller_mid = "MID"
        buyer.addresses.create! system_code: "2", name: "Buyer 2", line_1: "Addr1", line_2: "Addr2", city: "City", state: "ST", postal_code: "00000"
        entry_data.invoices.first.invoice_lines.first.buyer_customer_number = "BUY-2"

        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        buyer = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines/EdiInvoicePartyList/EdiInvoiceParty[partiesQualifier = 'BY']"
        expect(buyer).not_to be_nil
        expect(buyer.text "name").to eq "Buyer 2"
      end

      it "allows sending pieces_uom and unit price uom" do
        d = entry_data
        d.invoices.first.invoice_lines.first.pieces_uom = "PUOM"
        d.invoices.first.invoice_lines.first.unit_price_uom = "UUOM"

        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines"
        expect(t).not_to be_nil
        expect(t.text "uomCommercial").to eq "PUOM"
        expect(t.text "uomUnitPrice").to eq "UUOM"
      end

      it "raises an error if an MID is in the data but not in VFI Track" do
        entry_data.invoices.first.invoice_lines.first.seller_mid = "MID"
        expect {subject.generate_entry_xml entry_data, add_entry_info: false}.to raise_error OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::MissingCiLoadDataError, "No MID exists in VFI Track for 'MID'."
      end

      it "raises an error if an MID references an inactive MID" do
        entry_data.invoices.first.invoice_lines.first.seller_mid = "MID"
        mid
        mid.active = false
        mid.save!
        expect {subject.generate_entry_xml entry_data, add_entry_info: false}.to raise_error OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::MissingCiLoadDataError, "MID 'MID' is not an active MID."
      end

      it "raises an error if a Buyer is in the data but not in VFI Track" do
        entry_data.invoices.first.invoice_lines.first.buyer_customer_number = "BUY"
        expect {subject.generate_entry_xml entry_data, add_entry_info: false}.to raise_error OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::MissingCiLoadDataError, "No Customer Address # '1' found for 'BUY'."
      end

      it "allows for invoices to have distinct file numbers" do
        entry_data.file_number = nil
        entry_data.invoices.first.file_number = "INVOICE1"

        doc = subject.generate_entry_xml entry_data, add_entry_info: false
        root = doc.root
        expect(root).to have_xpath_value("request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/manufacturerId", "INVOICE1")
        expect(root).to have_xpath_value("request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines/manufacturerId", "INVOICE1")
      end

      it "defaults net weight uom to 'KG' if not given" do
        entry_data.invoices.first.invoice_lines.first.net_weight_uom = nil
        doc = subject.generate_entry_xml entry_data, add_entry_info: false
        t = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines"
        expect(t).not_to be_nil
        expect(t.text "netWtUom").to eq "KG"
      end

      let (:tariff_line) {
        t = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceTariff.new
        t.hts = "1234567890"
        t.spi = "JO"
        t.spi2 = "A+"
        t.foreign_value = BigDecimal("987.65")
        t.gross_weight = BigDecimal("12345")
        t.quantity_1 = BigDecimal("23.45")
        t.uom_1 = "U1"
        t.quantity_2 = BigDecimal("56.78")
        t.uom_2 = "U2"

        t
      }

      it "builds multiple tariff lines when tariff lines are present, identifying special tariffs and sorting accordingly" do
        tariff_1 = tariff_line
        tariff_2 = tariff_line.dup
        tariff_2.hts = "9903000000"
        entry_data.invoices.first.invoice_lines.first.tariff_lines = [tariff_1, tariff_2]

        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines"
        expect(t).not_to be_nil

        # There's going to be some key fields that are missing from the invoice line that have been "moved down" into tariff class records due to the presence of the
        # special tariff...validate that's the case
        expect(t.text "tariffNo").to be_nil

        tariffs = REXML::XPath.match(t, "EdiInvoiceTariffClassList/EdiInvoiceTariffClass").to_a
        expect(tariffs.length).to eq 2

        t1 = tariffs[0]
        expect(t1.text "manufacturerId").to eq "597549"
        expect(t1.text "commInvNo").to eq "15MSA10"
        expect(t1.text "dateInvoice").to eq "20151101"
        expect(t1.text "commInvLineNo").to eq "10"
        expect(t1.text "tariffLineNo").to eq "1"
        expect(t1.text "tariffNo").to eq "9903000000"
        expect(t1.text "weightGross").to eq "12345"
        expect(t1.text "kilosPounds").to eq "KG"
        expect(t1.text "valueForeign").to eq "98765"
        expect(t1.text "qty1Class").to eq "2345"
        expect(t1.text "uom1Class").to eq "U1"
        expect(t1.text "qty2Class").to eq "5678"
        expect(t1.text "uom2Class").to eq "U2"
        expect(t1.text "spiPrimary").to eq "JO"
        expect(t1.text "spiSecondary").to eq "A+"

        t2 = tariffs[1]
        expect(t2.text "manufacturerId").to eq "597549"
        expect(t2.text "commInvNo").to eq "15MSA10"
        expect(t2.text "dateInvoice").to eq "20151101"
        expect(t2.text "commInvLineNo").to eq "10"
        expect(t2.text "tariffLineNo").to eq "2"
        expect(t2.text "tariffNo").to eq "1234567890"
        expect(t2.text "weightGross").to eq "12345"
        expect(t2.text "kilosPounds").to eq "KG"
        expect(t2.text "valueForeign").to eq "98765"
        expect(t2.text "qty1Class").to eq "2345"
        expect(t2.text "uom1Class").to eq "U1"
        expect(t2.text "qty2Class").to eq "5678"
        expect(t2.text "uom2Class").to eq "U2"
        expect(t2.text "spiPrimary").to eq "JO"
        expect(t2.text "spiSecondary").to eq "A+"
      end

      it "automatically adds additional tariff lines if special tariff cross references exist" do
        SpecialTariffCrossReference.create! import_country_iso: "US", hts_number: "4202923031", country_origin_iso: "PH", effective_date_start: Date.new(2015, 11, 1), special_hts_number: "1111111111"

        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines"
        expect(t).not_to be_nil

        # There's going to be some key fields that are missing from the invoice line that have been "moved down" into tariff class records due to the presence of the
        # special tariff...validate that's the case
        expect(t.text "tariffNo").to be_nil

        tariffs = REXML::XPath.match(t, "EdiInvoiceTariffClassList/EdiInvoiceTariffClass").to_a
        expect(tariffs.length).to eq 2

        t1 = tariffs[0]
        expect(t1.text "manufacturerId").to eq "597549"
        expect(t1.text "commInvNo").to eq "15MSA10"
        expect(t1.text "dateInvoice").to eq "20151101"
        expect(t1.text "commInvLineNo").to eq "10"
        expect(t1.text "tariffLineNo").to eq "1"
        expect(t1.text "tariffNo").to eq "1111111111"
        expect(t1.text "weightGross").to eq "78"
        expect(t1.text "kilosPounds").to eq "KG"
        expect(t1.text "valueForeign").to be_nil
        expect(t1.text "qty1Class").to eq "9300"
        expect(t1.text "uom1Class").to eq "QT1"
        expect(t1.text "qty2Class").to eq "5200"
        expect(t1.text "uom2Class").to eq "QT2"
        expect(t1.text "spiPrimary").to eq "JO"
        expect(t1.text "spiSecondary").to eq "A+"

        t2 = tariffs[1]
        expect(t2.text "manufacturerId").to eq "597549"
        expect(t2.text "commInvNo").to eq "15MSA10"
        expect(t2.text "dateInvoice").to eq "20151101"
        expect(t2.text "commInvLineNo").to eq "10"
        expect(t2.text "tariffLineNo").to eq "2"
        expect(t2.text "tariffNo").to eq "4202923031"
        expect(t2.text "weightGross").to eq "78"
        expect(t2.text "kilosPounds").to eq "KG"
        # The commercial invoice value should stay with the original line
        expect(t2.text "valueForeign").to eq "317786"
        expect(t2.text "qty1Class").to eq "9300"
        expect(t2.text "uom1Class").to eq "QT1"
        expect(t2.text "qty2Class").to eq "5200"
        expect(t2.text "uom2Class").to eq "QT2"
        expect(t2.text "spiPrimary").to eq "JO"
        expect(t2.text "spiSecondary").to eq "A+"
      end

      it "automatically adds special tariff when multi-tariffs are present, sorting 9902 and 9903 tariff lines correctly" do
        SpecialTariffCrossReference.create! import_country_iso: "US", hts_number: "1234567890", country_origin_iso: "PH", effective_date_start: Date.new(2015, 11, 1), special_hts_number: "9903000000"

        tariff_1 = tariff_line
        tariff_2 = tariff_line.dup
        tariff_2.hts = "9902000000"
        tariff_2.foreign_value = nil
        entry_data.invoices.first.invoice_lines.first.tariff_lines = [tariff_1, tariff_2]

        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.match(doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines/EdiInvoiceTariffClassList/EdiInvoiceTariffClass").to_a
        expect(t).not_to be_nil
        expect(t.length).to eq 3

        # We can just verify the tariff numbers involved to tell that the special tariff was added in the right position
        expect(t[0].text "tariffNo").to eq "9903000000"
        expect(t[0].text "valueForeign").to be_nil
        expect(t[1].text "tariffNo").to eq "9902000000"
        expect(t[1].text "valueForeign").to be_nil
        expect(t[2].text "tariffNo").to eq "1234567890"
        expect(t[2].text "valueForeign").to eq "98765"
      end

      it "does not add special tariffs for tariff numbers that are already present in the tariff lines" do
        SpecialTariffCrossReference.create! import_country_iso: "US", hts_number: "1234567890", country_origin_iso: "PH", effective_date_start: Date.new(2015, 11, 1), special_hts_number: "9903000000"

        tariff_1 = tariff_line
        tariff_2 = tariff_line.dup
        tariff_2.hts = "9903000000"
        tariff_2.foreign_value = nil
        entry_data.invoices.first.invoice_lines.first.tariff_lines = [tariff_1, tariff_2]

        doc = subject.generate_entry_xml entry_data, add_entry_info: false

        t = REXML::XPath.match(doc.root, "request/kcData/ediShipments/ediShipment/EdiInvoiceHeaderList/EdiInvoiceHeader/EdiInvoiceLinesList/EdiInvoiceLines/EdiInvoiceTariffClassList/EdiInvoiceTariffClass").to_a
        expect(t).not_to be_nil
        expect(t.length).to eq 2

        # We can just verify the tariff numbers involved to tell that the special tariff was added in the right position
        expect(t[0].text "tariffNo").to eq "9903000000"
        expect(t[0].text "valueForeign").to be_nil
        expect(t[1].text "tariffNo").to eq "1234567890"
        expect(t[1].text "valueForeign").to eq "98765"
      end
    end
  end
end

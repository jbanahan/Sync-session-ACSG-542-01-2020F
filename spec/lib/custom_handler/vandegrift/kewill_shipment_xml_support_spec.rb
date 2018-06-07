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
        described_class::CiLoadBillsOfLading.new "CARR1234567890", "HBOL9876543210", "SUBH5678901234", "SSUB5432109876", BigDecimal(10), "BUOM"
      }

      let (:dates) {
        [
          described_class::CiLoadEntryDate.new(:est_arrival_date, Date.new(2018,3,1)),
          described_class::CiLoadEntryDate.new(:export_date, Date.new(2018,2,1))
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
        e.pieces = 5
        e.pieces_uom = "SUOM"
        e.goods_description = "DESC"
        e.weight_kg = BigDecimal("20")
        e.consignee_code = "CONSIGNEE"
        e.ultimate_consignee_code = "ULTCONS"
        e.country_of_origin = "OR"
        e.country_of_export = "EX"
        e.scac = "SCAC"

        e.dates = dates
        e.containers = [container]
        e.bills_of_lading = [bill_of_lading]

        e
      }

      it "builds entry xml" do
        doc = subject.generate_entry_xml entry

        # We're only concerned here with the data under ediShipment, the rest is tested elsewhere
        s = REXML::XPath.first doc.root, "request/kcData/ediShipments/ediShipment"
        expect(s).not_to be_nil

        expect(s.text "fileNo").to eq "12345"
        expect(s.text "custNo").to eq "CUST"
        expect(s.text "custRef").to eq "REF"
        expect(s.text "vesselAirlineName").to eq "VESSEL"
        expect(s.text "voyageFlightNo").to eq "VOYAGE"
        expect(s.text "scac").to eq "SCAC"
        expect(s.text "mot").to eq "10"
        expect(s.text "portLading").to eq "LPORT"
        expect(s.text "portDist").to eq "PORT"
        expect(s.text "dateEstArrival").to eq "20180301"
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

        expect(s.text "EdiShipmentIdList/EdiShipmentId/seqNo").to eq "1"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/masterBill").to eq "1234567890"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/houseBill").to eq "9876543210"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/subBill").to eq "5678901234"
        expect(s.text "EdiShipmentIdList/EdiShipmentId/subSubBill").to eq "5432109876"

        expect(s.text "EdiShipmentIdList/EdiShipmentId/scac").to eq "CARR"
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
        expect(s.text "EdiContainersList/EdiContainers/descr").to eq "DESC"
        expect(s.text "EdiContainersList/EdiContainers/pieces").to eq "30"
        expect(s.text "EdiContainersList/EdiContainers/uom").to eq "CUOM"
        expect(s.text "EdiContainersList/EdiContainers/weight").to eq "30"
        expect(s.text "EdiContainersList/EdiContainers/uomWeight").to eq "KG"
        expect(s.text "EdiContainersList/EdiContainers/containerType").to eq "CTYPE"
      end
    end

    context "with commercial invoice data" do
      let(:entry_data) {
        e = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new '597549', 'SALOMON', []
        i = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new '15MSA10', Date.new(2015,11,1), []
        i.non_dutiable_amount = BigDecimal("5")
        i.add_to_make_amount = BigDecimal("25")
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
        l.description = "Description"
        l.container_number = "ContainerNo"
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
        i.invoice_lines << l

        e
      }

      let (:buyer) { 
        c = Factory(:importer, alliance_customer_number: "BUY")
        c.addresses.create! system_code: "1", name: "Buyer", line_1: "Addr1", line_2: "Addr2", city: "City", state: "ST", country: Factory(:country, iso_code: "US"), postal_code: "00000"

        c
      }

      let (:mid) {
        ManufacturerId.create! mid: "MID", name: "Manufacturer", address_1: "Addr1", address_2: "Addr2", city: "City", country: "CO", postal_code: "00000", active: true
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
        expect(l.text "purchaseOrderNo").to eq "5301195481"
        expect(l.text "custRef").to eq "5301195481"
        expect(l.text "contract").to eq "218497.2"
        expect(l.text "department").to eq "1"
        expect(l.text "spiPrimary").to eq "JO"
        expect(l.text "nonDutiableAmt").to eq "2000"
        expect(l.text "addToMakeAmt").to eq "1500"
        expect(l.text "exemptionCertificate").to be_nil
        expect(l.text "manufacturerId2").to eq "PHMOUINS2106BAT"
        expect(l.text "cartons").to eq "1000"
        expect(l.text "detailLineNo").to eq "123"
        expect(l.text "countryExport").to eq "CE"
        expect(l.text "chargesAmt").to eq "20.25"
        expect(l.text "relatedParties").to eq "Y"
        expect(l.text "ftzQuantity").to eq "26"
        expect(l.text "descr").to eq "Description"
        expect(l.text "noContainer").to eq "ContainerNo"

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

      it "generates 999999999 as cert value when cotton fee flag is true" do
        mid
        d = entry_data
        d.invoices.first.invoice_lines.first.cotton_fee_flag = "Y"
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
    end
  end
end
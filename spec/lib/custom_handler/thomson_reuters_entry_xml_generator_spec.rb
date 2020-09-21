describe OpenChain::CustomHandler::ThomsonReutersEntryXmlGenerator do

  subject do
    s = described_class.new
    def s.root_name
      raise "Mock Me!"
    end
    allow(s).to receive(:root_name).and_return "rooty_root"
    s
  end

  describe "generate_xml" do
    it "generates an XML" do
      broker = Factory(:company, name: "Vandegrift Forwarding Co.", broker: true)
      broker.addresses.create!(system_code: "4", name: "Vandegrift Forwarding Co., Inc.", line_1: "180 E Ocean Blvd",
                               line_2: "Suite 270", city: "Long Beach", state: "CA", postal_code: "90802")
      broker.system_identifiers.create!(system: "Filer Code", code: "316")

      entry = Factory(:entry, entry_number: "31679758714", entry_type: "01", broker_reference: "ARGH58285",
                              lading_port_code: "57035", entry_port_code: "1402", transport_mode_code: 11,
                              ult_consignee_name: "Consignco",
                              release_date: ActiveSupport::TimeZone['UTC'].parse('2020-04-28 10:35:11'),
                              house_bills_of_lading: "EEEK142050488078\n EEEK142050488079",
                              master_bills_of_lading: "EGLV142050488082\n EGLV142050488083",
                              total_duty: BigDecimal("19.13"), entered_value: BigDecimal("22.16"))

      inv_1 = entry.commercial_invoices.build(invoice_number: "E1I0954293", currency: "USD",
                                              vendor_name: "Vendtech Prime", gross_weight: 15,
                                              master_bills_of_lading: "EGLV142050488076\n EGLV142050488077",
                                              house_bills_of_lading: "EEEK142050488080\n EEEK142050488081")
      inv_1_line_1 = inv_1.commercial_invoice_lines.build(po_number: "0082-1561840", part_number: "021004200-556677",
                                                          line_number: 3, vendor_name: "Vendtech", currency: "CAD",
                                                          value: BigDecimal("58.96"), value_foreign: BigDecimal("69.07"))
      inv_1_line_1.commercial_invoice_tariffs.build(gross_weight: 13, hts_code: "9506910030",
                                                    classification_uom_1: "NO", classification_qty_1: BigDecimal("2578"))
      inv_1_line_1.commercial_invoice_tariffs.build(hts_code: "99038815")
      inv_1_line_2 = inv_1.commercial_invoice_lines.build(po_number: "0082-1561841", part_number: "021004201-666777888",
                                                          line_number: 5)
      inv_1_line_2.commercial_invoice_tariffs.build(hts_code: "9506910030")

      inv_2 = entry.commercial_invoices.build(invoice_number: "E1I0954294", currency: "AUD", gross_weight: 10)
      inv_2_line = inv_2.commercial_invoice_lines.build(po_number: "0082-1561847", line_number: 2)
      inv_2_line.commercial_invoice_tariffs.build(hts_code: "9506910030")

      doc = subject.generate_xml entry

      elem_root = doc.root
      expect(elem_root.name).to eq "rooty_root"

      elem_dec = elem_root.elements.to_a("Declaration")[0]
      expect(elem_dec).not_to be_nil
      expect(elem_dec.text("EntryNum")).to eq "31679758714"
      expect(elem_dec.text("BrokerFileNum")).to eq "ARGH58285"
      expect(elem_dec.text("BrokerID")).to eq "316"
      expect(elem_dec.text("BrokerName")).to eq "Vandegrift Inc"
      expect(elem_dec.text("EntryType")).to eq "01"
      expect(elem_dec.text("PortOfEntry")).to eq "1402"
      expect(elem_dec.text("UltimateConsignee")).to eq "Consignco"
      expect(elem_dec.text("ReleaseDate")).to eq "2020-04-28 10:35:11"
      expect(elem_dec.text("TotalEnteredValue")).to eq "22.16"
      expect(elem_dec.text("CurrencyCode")).to eq "USD"
      expect(elem_dec.text("ModeOfTransport")).to eq "11"
      expect(elem_dec.text("PortOfLading")).to eq "57035"
      expect(elem_dec.text("TotalDuty")).to eq "19.13"

      line_elements = elem_dec.elements.to_a("DeclarationLine")
      expect(line_elements.size).to eq 4

      elem_line_1 = line_elements[0]
      expect(elem_line_1.text("SupplierName")).to eq "Vendtech"
      expect(elem_line_1.text("InvoiceNum")).to eq "E1I0954293"
      expect(elem_line_1.text("PurchaseOrderNum")).to eq "0082-1561840"
      expect(elem_line_1.text("LineNum")).to eq "1"
      expect(elem_line_1.text("MasterBillOfLading")).to eq "EGLV142050488076"
      expect(elem_line_1.text("HouseBillOfLading")).to eq "EEEK142050488080"
      expect(elem_line_1.text("ProductNum")).to eq "021004200-556677"
      expect(elem_line_1.text("HsNum")).to eq "9506910030"
      expect(elem_line_1.text("GrossWeight")).to eq "13"
      expect(elem_line_1.text("TxnQty")).to eq "2578"
      expect(elem_line_1.text("LineValue")).to eq "58.96"
      expect(elem_line_1.text("InvoiceCurrency")).to eq "CAD"
      expect(elem_line_1.text("InvoiceQty")).to eq "2578"
      expect(elem_line_1.text("InvoiceValue")).to eq "69.07"
      expect(elem_line_1.text("TxnQtyUOM")).to eq "NO"
      expect(elem_line_1.text("WeightUOM")).to eq "KG"

      elem_line_2 = line_elements[1]
      expect(elem_line_2.text("InvoiceNum")).to eq "E1I0954293"
      expect(elem_line_2.text("PurchaseOrderNum")).to eq "0082-1561840"
      expect(elem_line_2.text("LineNum")).to eq "2"
      expect(elem_line_2.text("HsNum")).to eq "99038815"

      elem_line_3 = line_elements[2]
      expect(elem_line_3.text("SupplierName")).to eq "Vendtech Prime"
      expect(elem_line_3.text("InvoiceNum")).to eq "E1I0954293"
      expect(elem_line_3.text("PurchaseOrderNum")).to eq "0082-1561841"
      expect(elem_line_3.text("LineNum")).to eq "3"
      expect(elem_line_3.text("HsNum")).to eq "9506910030"

      elem_line_4 = line_elements[3]
      expect(elem_line_4.text("InvoiceNum")).to eq "E1I0954294"
      expect(elem_line_4.text("PurchaseOrderNum")).to eq "0082-1561847"
      expect(elem_line_4.text("LineNum")).to eq "4"
      expect(elem_line_4.text("MasterBillOfLading")).to eq "EGLV142050488082"
      expect(elem_line_4.text("HouseBillOfLading")).to eq "EEEK142050488078"
      expect(elem_line_4.text("HsNum")).to eq "9506910030"
      expect(elem_line_4.text("GrossWeight")).to eq "10"
      expect(elem_line_4.text("InvoiceCurrency")).to eq "AUD"
    end
  end

end
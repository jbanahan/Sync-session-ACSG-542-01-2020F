describe OpenChain::CustomHandler::Rockport::RockportGtnInvoiceXmlParser do

  let (:xml_data_therock) {
    IO.read 'spec/fixtures/files/gtn_rockport_invoice.xml'
  }

  let (:xml_data_reef) {
    IO.read 'spec/fixtures/files/gtn_reef_invoice.xml'
  }

  let (:xml_data_error) {"
    <Invoice>
      <header>
        <version>310</version>
        <documentType>Invoice</documentType>
        <messageId>1234567890</messageId>
        <count>1</count>
      </header>
      <invoiceDetail>
        <subscriptionEvent>
          <eventTypeCode>InvoiceActivatedEvent</eventTypeCode>
          <eventRoleCode>CustomsBroker</eventRoleCode>
          <eventDate>2019-10-12</eventDate>
          <eventDateTime>2019-10-12T07:01:38Z</eventDateTime>
        </subscriptionEvent>
        <invoiceNumber>INV12345678901234</invoiceNumber>
        <party>
          <partyUid>0987654321</partyUid>
          <partyRoleCode>Consignee</partyRoleCode>
          <name>Some other team which is not Rock or Reef</name>
        </party>
      </invoiceDetail>
    </Invoice>"
  }

  let (:xml_therock) {
    REXML::Document.new(xml_data_therock)
  }

  let (:xml_reef) {
    REXML::Document.new(xml_data_reef)
  }

  let (:xml_error) {
    REXML::Document.new(xml_data_error)
  }

  let (:invoice_xml_therock) {
    REXML::XPath.first(xml_therock, "/Invoice/invoiceDetail")
  }

  let (:invoice_xml_reef) {
    REXML::XPath.first(xml_reef, "/Invoice/invoiceDetail")
  }

  let (:invoice_xml_error) {
    REXML::XPath.first(xml_error, "/Invoice/invoiceDetail")
  }

  let (:taiwan) { Factory(:country, iso_code: "TW") }
  let (:china) { Factory(:country, iso_code: "CN") }
  let (:biot) { Factory(:country, iso_code: "IO") }
  let (:vietnam) { Factory(:country, iso_code: "VN") }

  let (:theroc) {
    ro = Factory(:importer, system_code: "THEROC")
    ro.set_system_identifier "GT Nexus Invoice Consignee", "106320777927"
    ro
  }

  let (:reef) {
    re = Factory(:importer, system_code: "REEF")
    re.set_system_identifier "GT Nexus Invoice Consignee", "117965977957"
    re
  }

  let! (:someother) {
    re = Factory(:importer, system_code: "OTHER")
    re.set_system_identifier "GT Nexus Invoice Consignee", "0987654321"
    re
  }

  let (:sys1) { }
  let (:user) { Factory(:user) }
  let (:inbound_file) { InboundFile.new }

  describe "process_invoice" do
    before :each do
      china
      taiwan
      biot
      vietnam
      theroc
      reef
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses an invoice from xml and correctly reads it as rockport" do
      i = subject.process_invoice invoice_xml_therock, user, "bucket", "key"

      expect(i).not_to be_nil

      expect(i.importer).to eq theroc
      expect(i.invoice_number).to eq "INV106320777908"
      expect(i.last_exported_from_source).to eq Time.zone.parse("2019-10-12T07:01:38Z")
      expect(i.last_file_bucket).to eq "bucket"
      expect(i.last_file_path).to eq "key"

      expect(i.invoice_date).to eq Date.new(2019, 9, 28)
      expect(i.terms_of_sale).to eq "FOB"
      expect(i.currency).to eq "USD"
      expect(i.ship_mode).to eq "Ocean"

      expect(i.invoice_total_foreign).to eq BigDecimal("24133.26")
      expect(i.invoice_total_domestic).to eq BigDecimal("24133.26")
      expect(i.total_charges).to eq 0
      expect(i.total_discounts).to eq 0

      expect(i.entity_snapshots.length).to eq 1
      s = i.entity_snapshots.first
      expect(s.context).to eq "key"
      expect(s.user).to eq user

      v = i.vendor
      expect(v).not_to be_nil
      expect(v).to have_system_identifier("THEROC-GTN Vendor", "5717989018225654")
      expect(v.name).to eq "CHUNG JYE SHOES HOLDINGS LIMITED"
      expect(v.addresses.length).to eq 1
      a = v.addresses.first
      expect(a.system_code).to eq "THEROC-GTN Vendor-5717989018225654"
      expect(a.address_type).to eq "Vendor"
      expect(a.name).to eq "CHUNG JYE SHOES HOLDINGS LIMITED"
      expect(a.line_1).to eq "NO.628, SEC.4,CHUNG CHIN ROAD"
      expect(a.line_2).to eq "TA YA DISTRICT"
      expect(a.city).to eq "TAICHUNG"
      expect(a.postal_code).to eq "000"
      expect(a.country).to eq taiwan
      expect(theroc.linked_companies).to include v

      expect(i.invoice_lines.length).to eq 42

      l = i.invoice_lines.first

      expect(l.line_number).to eq 1
      expect(l.po_number).to eq "4500051936"
      expect(l.part_number).to eq "A13010-080-M"
      expect(l.hts_number).to eq "6403996075"
      expect(l.part_description).to eq "Sl2 Bike Toe Ox Black 080 M"
      expect(l.quantity).to eq BigDecimal("24")
      expect(l.quantity_uom).to eq "PR"
      expect(l.unit_price).to eq BigDecimal("20.26")
      expect(l.value_foreign).to eq BigDecimal("486.24")
      expect(l.country_origin).to eq china

      l = i.invoice_lines.second

      expect(l.line_number).to eq 2
      expect(l.po_number).to eq "4500051936"
      expect(l.part_number).to eq "A13010-085-M"
      expect(l.hts_number).to eq "6403996075"
      expect(l.part_description).to eq "Sl2 Bike Toe Ox Black 085 M"
      expect(l.quantity).to eq BigDecimal("30")
      expect(l.quantity_uom).to eq "PR"
      expect(l.unit_price).to eq BigDecimal("20.26")
      expect(l.value_foreign).to eq BigDecimal("607.80")

      expect(l.country_origin).to eq china
      # This is all nil on purpose, because i don't want the missing line
      # to error the commercial invoice.
      expect(l.order_line).to be_nil
      expect(l.order).to be_nil
      expect(l.product).to be_nil
    end

    it "parses an invoice from xml and correctly reads it as reef" do
      i = subject.process_invoice invoice_xml_reef, user, "bucket", "key"

      expect(i).not_to be_nil

      expect(i.importer).to eq reef
      expect(i.invoice_number).to eq "INV117965977906"
      expect(i.last_exported_from_source).to eq Time.zone.parse("2020-02-13T09:14:01Z")
      expect(i.last_file_bucket).to eq "bucket"
      expect(i.last_file_path).to eq "key"

      expect(i.invoice_date).to eq Date.new(2020, 2, 11)
      expect(i.terms_of_sale).to eq "FCA"
      expect(i.currency).to eq "USD"
      expect(i.ship_mode).to eq "Ocean"

      expect(i.invoice_total_foreign).to eq BigDecimal("150411.12")
      expect(i.invoice_total_domestic).to eq BigDecimal("150411.12")
      expect(i.total_charges).to eq 0
      expect(i.total_discounts).to eq 0

      expect(i.entity_snapshots.length).to eq 1
      s = i.entity_snapshots.first
      expect(s.context).to eq "key"
      expect(s.user).to eq user

      v = i.vendor
      expect(v).not_to be_nil
      expect(v).to have_system_identifier("REEF-GTN Vendor", "5717989018249725")
      expect(v.name).to eq "TOP CRYSTAL LTD."
      expect(v.addresses.length).to eq 1
      a = v.addresses.first
      expect(a.system_code).to eq "REEF-GTN Vendor-5717989018249725"
      expect(a.address_type).to eq "Vendor"
      expect(a.name).to eq "TOP CRYSTAL LTD."
      expect(a.line_1).to eq "ROAD TOWN"
      expect(a.line_2).to eq "JIPFA BUILDING, 3RD FLOOR"
      expect(a.city).to eq "TORTOLA"
      expect(a.postal_code).to eq "00000"
      expect(a.country).to eq biot
      expect(reef.linked_companies).to include v

      expect(i.invoice_lines.length).to eq 163

      l = i.invoice_lines.first

      expect(l.line_number).to eq 1
      expect(l.po_number).to eq "4000994340"
      expect(l.part_number).to eq "RF0A3YOWCLD-070-M"
      expect(l.hts_number).to eq "6402993165"
      expect(l.part_description).to eq "REEF CUSHION SANDS CLOUD 070 M"
      expect(l.quantity).to eq BigDecimal("828")
      expect(l.quantity_uom).to eq "PR"
      expect(l.unit_price).to eq BigDecimal("6.31")
      expect(l.value_foreign).to eq BigDecimal("5224.68")
      expect(l.country_origin).to eq vietnam

      l = i.invoice_lines.second

      expect(l.line_number).to eq 2
      expect(l.po_number).to eq "4000994340"
      expect(l.part_number).to eq "RF0A3YOWCLD-100-M"
      expect(l.hts_number).to eq "6402993165"
      expect(l.part_description).to eq "REEF CUSHION SANDS CLOUD 100 M"
      expect(l.quantity).to eq BigDecimal("288")
      expect(l.quantity_uom).to eq "PR"
      expect(l.unit_price).to eq BigDecimal("6.31")
      expect(l.value_foreign).to eq BigDecimal("1817.28")

      expect(l.country_origin).to eq vietnam
      # This is all nil on purpose, because i don't want the missing line
      # to error the commercial invoice.
      expect(l.order_line).to be_nil
      expect(l.order).to be_nil
      expect(l.product).to be_nil
    end

    it "errors if the correct importer system code cannot be found" do
      expect { subject.process_invoice invoice_xml_error, user, "bucket", "key" }.to raise_error "Customer system code OTHER is not valid for this parser. Parser is only for Rockport and Reef."
    end
  end
end

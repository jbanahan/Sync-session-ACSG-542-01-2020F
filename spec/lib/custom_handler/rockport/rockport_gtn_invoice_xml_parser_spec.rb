describe OpenChain::CustomHandler::Rockport::RockportGtnInvoiceXmlParser do

  let (:xml_data) {
    IO.read 'spec/fixtures/files/gtn_rockport_invoice.xml'
  }

  let (:xml) {
    REXML::Document.new(xml_data)
  }

  let (:invoice_xml) {
    REXML::XPath.first(xml, "/Invoice/invoiceDetail")
  }

  let! (:uom) { UnitOfMeasure.create! uom: "PCS", description: "Peices" }
  let! (:data_cross_reference) { DataCrossReference.create! cross_reference_type: "unit_of_measure", key: uom.uom, value: "PR"}

  let (:taiwan) { Factory(:country, iso_code: "TW") }
  let (:china) { Factory(:country, iso_code: "CN") }
  let (:theroc) { Factory(:importer, system_code: "THEROC") }
  let (:user) { Factory(:user) }
  let (:inbound_file) { InboundFile.new }

  describe "process_invoice" do
    before :each do
      china
      taiwan
      theroc
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses an invoice from xml" do
      i = subject.process_invoice invoice_xml, user, "bucket", "key"

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
  end
end

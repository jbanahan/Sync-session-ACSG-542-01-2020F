describe OpenChain::CustomHandler::Pvh::PvhGtnInvoiceXmlParser do

  let (:xml_data) {
    IO.read 'spec/fixtures/files/gtn_pvh_invoice.xml'
  }

  let (:xml) {
    REXML::Document.new(xml_data)
  }

  let (:invoice_xml) {
    REXML::XPath.first(xml, "/Invoice/invoiceDetail")
  }

  let (:india) { create(:country, iso_code: "IN") }
  let (:ca) { create(:country, iso_code: "CA") }
  let (:pvh) { create(:importer, system_code: "PVH") }
  let (:user) { create(:user) }
  let (:order) { create(:order, order_number: "PVH-RTTC216384", importer: pvh)}
  let (:product) { create(:product, unique_identifier: "PVH-7695775") }
  let (:order_line) { create(:order_line, order: order, line_number: 1, product: product) }
  let (:inbound_file) { InboundFile.new }

  describe "process_invoice" do
    before :each do
      india
      ca
      pvh
      order_line
      allow(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses an invoice from xml" do
      i = subject.process_invoice invoice_xml, user, "bucket", "key"

      expect(i).not_to be_nil

      expect(i.importer).to eq pvh
      expect(i.invoice_number).to eq "EEGC/7469/1819"
      expect(i.last_exported_from_source).to eq Time.zone.parse("2018-08-24T06:45:12Z")
      expect(i.last_file_bucket).to eq "bucket"
      expect(i.last_file_path).to eq "key"

      expect(i.invoice_date).to eq Date.new(2018, 8, 6)
      expect(i.terms_of_sale).to eq "FOB"
      expect(i.currency).to eq "USD"
      expect(i.ship_mode).to eq "Air"
      expect(i.net_weight).to eq BigDecimal("608.36")
      expect(i.net_weight_uom).to eq "KG"
      expect(i.gross_weight).to eq BigDecimal("766.85")
      expect(i.gross_weight_uom).to eq "KG"
      expect(i.volume).to eq BigDecimal("5.445")
      expect(i.volume_uom).to eq "CR"
      expect(i.invoice_total_foreign).to eq BigDecimal("3574.08")
      expect(i.invoice_total_domestic).to eq BigDecimal("3574.08")
      expect(i.total_charges).to eq 0
      expect(i.total_discounts).to eq 0

      expect(i.entity_snapshots.length).to eq 1
      s = i.entity_snapshots.first
      expect(s.context).to eq "key"
      expect(s.user).to eq user

      expect(i.customer_reference_number).to eq "63479868585"

      v = i.vendor
      expect(v).not_to be_nil
      expect(v).to have_system_identifier("PVH-GTN Vendor", "23894")
      expect(v.name).to eq "EASTMAN EXPORTS GLOBAL-"
      expect(v.addresses.length).to eq 1
      a = v.addresses.first
      expect(a.system_code).to eq "PVH-GTN Vendor-23894"
      expect(a.address_type).to eq "Vendor"
      expect(a.name).to eq "EASTMAN EXPORTS GLOBAL-"
      expect(a.line_1).to eq "5/591 SRI LAKSHMI NAGAR"
      expect(a.line_2).to eq "PITCHAMPALAYAM PUDUR, TIRUPUR"
      expect(a.city).to eq "TAMILNADU"
      expect(a.postal_code).to eq "641603"
      expect(a.country).to eq india
      expect(pvh.linked_companies).to include v

      co = i.consignee
      expect(co).not_to be_nil
      expect(co).to have_system_identifier("PVH-GTN Consignee", "CNTC")
      expect(co.name).to eq "PVH CANADA, INC."
      expect(co.addresses.length).to eq 1
      a = co.addresses.first
      expect(a.system_code).to eq "PVH-GTN Consignee-CNTC"
      expect(a.address_type).to eq "Consignee"
      expect(a.name).to eq "PVH CANADA, INC."
      expect(a.line_1).to eq "555 Richmond Street"
      expect(a.city).to eq "Toronto,"
      expect(a.state).to eq "ON"
      expect(a.postal_code).to eq "M5V 3B1"
      expect(a.country).to eq ca
      expect(pvh.linked_companies).to include co

      expect(pvh.addresses.length).to eq 1
      st = pvh.addresses.first
      expect(st.system_code).to eq "PVH-GTN Ship To-PVH Canada, Inc. 55"
      expect(st.address_type).to eq "Ship To"
      expect(st.line_1).to eq "7445 Cote-de Liesse"
      expect(st.city).to eq "Montreal, QC"
      expect(st.postal_code).to eq "H4T 1G2"
      expect(st.country).to eq ca

      expect(i.invoice_lines.length).to eq 2

      l = i.invoice_lines.first

      expect(l.line_number).to eq 1
      expect(l.po_number).to eq "RTTC216384"
      expect(l.part_number).to eq "7695775"
      expect(l.hts_number).to eq "6109100022"
      expect(l.part_description).to eq "WOMENS KNIT T-SHIRT"
      expect(l.quantity).to eq BigDecimal("324")
      expect(l.quantity_uom).to eq "EA"
      expect(l.unit_price).to eq BigDecimal("5.84")
      expect(l.value_foreign).to eq BigDecimal("1892.16")

      expect(l.fish_wildlife).to eq true
      expect(l.mid).to eq "INRODAPP2TIR"
      expect(l.country_origin).to eq india
      expect(l.cartons).to eq 27
      expect(l.customs_quantity).to eq BigDecimal("324")
      expect(l.order_line).to eq order_line
      expect(l.order).to eq order
      expect(l.product).to eq product

      l = i.invoice_lines.second

      expect(l.line_number).to eq 2
      expect(l.po_number).to eq "RTTC216384"
      expect(l.part_number).to eq "7695775"
      expect(l.hts_number).to eq "6109100022"
      expect(l.part_description).to eq "WOMENS KNIT T-SHIRT"
      expect(l.quantity).to eq BigDecimal("288")
      expect(l.quantity_uom).to eq "EA"
      expect(l.unit_price).to eq BigDecimal("5.84")
      expect(l.value_foreign).to eq BigDecimal("1681.92")

      expect(l.fish_wildlife).to eq false
      expect(l.mid).to eq "INRODAPP2TIR"
      expect(l.country_origin).to eq india
      # This is all nil on purpose, because i don't want the missing line
      # to error the commercial invoice.
      expect(l.order_line).to be_nil
      expect(l.order).to be_nil
      expect(l.product).to be_nil
    end

    it "falls back to Consignee party's name as the identifier if ConsigeeCode is missing" do
      xml_data.gsub!("<type>ConsigneeCode</type>", "")

      i = subject.process_invoice invoice_xml, user, "bucket", "key"
      expect(i).not_to be_nil
      co = i.consignee
      expect(co).not_to be_nil
      expect(co).to have_system_identifier("PVH-GTN Consignee", "PVH CANADA, INC.")
      expect(co.name).to eq "PVH CANADA, INC."
    end
  end
end
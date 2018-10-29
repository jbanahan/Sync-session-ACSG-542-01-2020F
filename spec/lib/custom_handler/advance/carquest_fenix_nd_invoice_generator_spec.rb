describe OpenChain::CustomHandler::Advance::CarquestFenixNdInvoiceGenerator do

  let (:consignee) {
    c = Factory(:company, name: "Consignee")
    c.addresses.create! line_1: "Con Line 1"
    c 
  }

  let (:ship_to) {
    Factory(:address, name: "Ship To", line_1: "SF Line 1")
  }

  let (:ship_from) {
    Factory(:address, name: "Ship From", line_1: "SF Line 1")
  }

  let (:product) {
    p = Factory(:product, name: "Description")
    p.update_custom_value! cdefs[:prod_part_number], "PART"
    p.update_hts_for_country(ca, "1234567890")

    p
  }

  let (:ca) {
    Factory(:country, iso_code: "CA")
  }

  let (:order) {
    o = Factory(:order, order_number: "Order", customer_order_number: "Cust Order")
    o.order_lines.create! product_id: product.id, price_per_unit: BigDecimal("5"), country_of_origin: "CN"

    o
  }

  let (:cdefs) {
    subject.cdefs
  }

  let (:shipment) {
    s = Factory(:shipment, house_bill_of_lading: "SCAC123456", consignee_id: consignee.id, ship_from_id: ship_from.id, ship_to_id: ship_to.id)
    line = s.shipment_lines.build quantity: 10, product_id: product.id, invoice_number: "INV"
    line.linked_order_line_id = order.order_lines.first.id
    line.save!

    s
  }

  describe "generate_invoices" do

    it "generates an invoice from a shipment" do
      invoices = subject.generate_invoices shipment
      expect(invoices.length).to eq 1

      i = invoices.first
      expect(i.invoice_number).to eq "INV"
      expect(i.invoice_date).to eq ActiveSupport::TimeZone["America/New_York"].now.to_date
      
      expect(i.consignee).to eq consignee
      # The vendor / importer aren't a straight copy, we're turning an address into a fake company
      v = i.vendor
      expect(v.name).to eq "Ship From"
      expect(v.addresses.first).to eq ship_from

      st = i.importer
      expect(st.name).to eq "Ship To"
      expect(st.addresses.first).to eq ship_to

      expect(i.master_bills_of_lading).to eq "SCAC123456"
      expect(i.currency).to eq "USD"
      expect(i.country_origin_code).to eq "CN"

      expect(i.commercial_invoice_lines.length).to eq 1
      l = i.commercial_invoice_lines.first

      expect(l.part_number).to eq "PART"
      expect(l.po_number).to eq "Cust Order"
      expect(l.quantity).to eq 10
      expect(l.unit_price).to eq 5
      expect(l.country_origin_code).to eq "CN"
      expect(l.commercial_invoice_tariffs.length).to eq 1
      t = l.commercial_invoice_tariffs.first
      expect(t.hts_code).to eq "1234567890"
      expect(t.tariff_description).to eq "Description"
    end
  end

  describe "generate_invoice_and_send" do

    def verify_company_fields l, i, c
      ranges = [(i..i+49), (i+50..i+99), (i+100..i+149), (i+150..i+199), (i+200..i+249), (i+250..i+299), (i+300..i+349), (i+350..i+399)]

      expect(l[ranges[0]]).to eq(c.name.ljust(50))
      expect(l[ranges[1]]).to eq(c.name_2.to_s.ljust(50))

      a = c.addresses.blank? ? Address.new : c.addresses.first
      expect(l[ranges[2]]).to eq(a.line_1.to_s.ljust(50))
      expect(l[ranges[3]]).to eq(a.line_2.to_s.ljust(50))
      expect(l[ranges[4]]).to eq(a.city.to_s.ljust(50))
      expect(l[ranges[5]]).to eq(a.state.to_s.ljust(50))
      expect(l[ranges[6]]).to eq(a.postal_code.to_s.ljust(50))
    end

    it "generates an invoice file and sends it" do
      # We're intercepting the actual ftp so we can capture the lines and validate 
      # the correct data was generated..since  we're overriding a field or to 
      # in the generation.
      file_contents = nil
      sr = SyncRecord.new
      expect(subject).to receive(:ftp_sync_file) do |file, sync_record, ftp_information|
        expect(sync_record).to eq sr
        file_contents = file.read
      end

      subject.generate_invoice_and_send shipment, sr

      expect(file_contents).not_to be_nil
      contents = file_contents.split("\r\n").first

      # Just validate the importer data is present
      c = Company.new name: ship_to.name
      c.addresses << ship_to

      verify_company_fields(contents, 820, c)
    end
  end

  describe "ftp_folder" do
    it "uses correct folder" do
      expect(subject.ftp_folder).to eq "to_ecs/fenix_invoices/CQ"
    end
  end

end
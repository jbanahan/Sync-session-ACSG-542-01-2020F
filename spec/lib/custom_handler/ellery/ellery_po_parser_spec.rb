describe OpenChain::CustomHandler::Ellery::ElleryOrderParser do

  before(:all) {
    described_class.new.send(:cdefs)
  }

  after(:all) {
    CustomDefinition.destroy_all
  }

  let (:po_csv) {
    '1,"0020","BE1220","United Linens Limited(Benetex)","Suite 701, Bldg. No. 1","Art & Tech Space","63 Haier Road","Qingdao","State","266061","CHI",14945,20160519,20160713,"FAYETTEVILLE DC","107 TOM STARLING RD.","FAYETTEVILLE","NC","28306","USA","USD","QINDG","FAYD","FAYETTEVILLE - DOMESTI","ANUNEZ","O/A 90 DAYS",3,"15828052084MAR","885308443519","BELK","DERON DISPLAY","052084","MARBLE",1.0000,1.0000,"WINDOW","DISPLAYS","DISPLAY","DERON",1,2,"6303.92.2010",20160713,8.5000,55.00,.00,123' + "\n" +
    '1,"0020","BE1220","United Linens Limited(Benetex)","Suite 701, Bldg. No. 1","Art & Tech Space","63 Haier Road","Qingdao","State","266061","CHI",14945,20160519,20160713,"FAYETTEVILLE DC","107 TOM STARLING RD.","FAYETTEVILLE","NC","28306","USA","USD","QINDG","FAYD","FAYETTEVILLE - DOMESTI","ANUNEZ","O/A 90 DAYS",4,"15828052084LAK","885308443526","BELK","DERON DISPLAY","052084","LAKE",1.0000,1.0000,"WINDOW","DISPLAYS","DISPLAY","DERON",2,3,"6303.92.2010",20160713,8.5000,55.00,.00,123'
  }

  let! (:ellery) { Factory(:importer, system_code: "ELLERY") }
  let! (:us) { Factory(:country, iso_code: "US", iso_3_code: "USA") }
  let! (:china) { Factory(:country, iso_code: "CN", iso_3_code: "CHN" )}

  describe "parse" do
    subject { described_class }

    let (:parser) {
      described_class.new
    }

    let (:cdefs) {
      parser.send(:cdefs)
    }

    before :each do 
      allow(subject).to receive(:parser_instance).and_return parser
    end

    it "parses CSV data and creates an order" do
      subject.parse po_csv, bucket: "bucket", key: "path/to/file.csv"

      o = Order.where(order_number: "ELLERY-14945").first
      expect(o).not_to be_nil

      expect(o.importer).to eq ellery
      expect(o.customer_order_number).to eq "14945"
      expect(o.custom_value(cdefs[:ord_division])).to eq "1"
      expect(o.custom_value(cdefs[:ord_destination_code])).to eq "0020"
      expect(o.order_date).to eq Date.new(2016, 5, 19)
      expect(o.ship_window_end).to eq Date.new(2016, 7, 13)
      expect(o.currency).to eq "USD"
      expect(o.fob_point).to eq "QINDG"
      expect(o.mode).to eq "FAYD"
      expect(o.custom_value(cdefs[:ord_ship_type])).to eq "FAYETTEVILLE - DOMESTI"
      expect(o.custom_value(cdefs[:ord_buyer])).to eq "ANUNEZ"
      expect(o.terms_of_payment).to eq "O/A 90 DAYS"
      expect(o.custom_value(cdefs[:ord_customer_code])).to eq "BELK"
      expect(o.custom_value(cdefs[:ord_buyer_order_number])).to eq "123"
      expect(o.last_file_bucket).to eq "bucket"
      expect(o.last_file_path).to eq "path/to/file.csv"

      # Verify that a fingerprint was also saved
      xref = DataCrossReference.find_po_fingerprint o
      expect(xref).not_to be_nil

      expect(o.entity_snapshots.length).to eq 1
      snap = o.entity_snapshots.first
      expect(snap.user).to eq User.integration
      expect(snap.context).to eq "path/to/file.csv"

      v = o.vendor
      expect(v).not_to be_nil
      expect(v.system_code).to eq "ELLERY-BE1220"
      expect(v.name).to eq "United Linens Limited(Benetex)"
      a = v.addresses.first
      expect(a).not_to be_nil
      expect(a.system_code).to eq "ELLERY-BE1220"
      expect(a.line_1).to eq "Suite 701, Bldg. No. 1"
      expect(a.line_2).to eq "Art & Tech Space"
      expect(a.line_3).to eq "63 Haier Road"
      expect(a.city).to eq "Qingdao"
      expect(a.state).to eq "State"
      expect(a.postal_code).to eq "266061"
      expect(a.country).to eq china
      expect(ellery.linked_companies).to include v

      s = o.ship_to
      expect(s).not_to be_nil
      expect(s.name).to eq "FAYETTEVILLE DC"
      expect(s.line_1).to eq "107 TOM STARLING RD."
      expect(s.city).to eq "FAYETTEVILLE"
      expect(s.state).to eq "NC"
      expect(s.postal_code).to eq "28306"
      expect(s.country).to eq us
      expect(ellery.addresses).to include s

      expect(o.order_lines.length).to eq 2
      l = o.order_lines.first
      expect(l.line_number).to eq 1
      expect(l.sku).to eq "885308443519"
      expect(l.hts).to eq "6303922010"
      expect(l.price_per_unit).to eq BigDecimal("8.5")
      expect(l.quantity).to eq BigDecimal("55")
      expect(l.custom_value(cdefs[:ord_line_size])).to eq "052084"
      expect(l.custom_value(cdefs[:ord_line_color])).to eq "MARBLE"
      expect(l.custom_value(cdefs[:ord_line_division])).to eq "WINDOW"
      expect(l.custom_value(cdefs[:ord_line_units_per_inner_pack])).to eq BigDecimal("2")
      expect(l.custom_value(cdefs[:ord_line_planned_available_date])).to eq Date.new(2016,7,13)

      p = l.product
      expect(p).not_to be_nil
      expect(p.unique_identifier).to eq "ELLERY-15828052084MAR"
      expect(p.importer).to eq ellery
      expect(p.name).to eq "DERON DISPLAY"
      expect(p.custom_value(cdefs[:prod_part_number])).to eq "15828052084MAR"
      expect(p.custom_value(cdefs[:prod_class])).to eq "DISPLAYS"
      expect(p.custom_value(cdefs[:prod_product_group])).to eq "DISPLAY"
      expect(p.hts_for_country(us)).to eq ["6303922010"]

      expect(p.entity_snapshots.length).to eq 1
      snap = p.entity_snapshots.first
      expect(snap.user).to eq User.integration
      expect(snap.context).to eq "path/to/file.csv"
    end

    it "updates an order" do
      existing = Factory(:order, importer: ellery, order_number: "ELLERY-14945")
      existing_line = Factory(:order_line, order: existing)

      subject.parse po_csv, bucket: "bucket", key: "path/to/file.csv"

      existing.reload
      # Make sure the data was loaded to the existing PO
      expect(existing.customer_order_number).to eq "14945"

      # Make sure there's 2 lines
      expect(existing.order_lines.length).to eq 2

      # Make sure the existing line was destroyed
      expect { existing_line.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it "does not delete unreferenced order lines that have been booked" do
      existing = Factory(:order, importer: ellery, order_number: "ELLERY-14945")
      existing_line = Factory(:order_line, order: existing)
      booking_line = Factory(:booking_line, product: existing_line.product, order_line: existing_line, order: existing)

      subject.parse po_csv, bucket: "bucket", key: "path/to/file.csv"

      existing.reload

      # Make sure there's 3 lines
      expect(existing.order_lines.length).to eq 3

      # Make sure the existing line was not destroyed
      expect { existing_line.reload }.not_to raise_error
    end

    it "does not delete unreferenced order lines that have been shipped" do
      existing = Factory(:order, importer: ellery, order_number: "ELLERY-14945")
      existing_line = Factory(:order_line, order: existing)
      shipment_line = Factory(:shipment_line, product: existing_line.product)
      piece_set = PieceSet.create! order_line: existing_line, shipment_line: shipment_line, quantity: 100

      subject.parse po_csv, bucket: "bucket", key: "path/to/file.csv"

      existing.reload

      # Make sure there's 3 lines
      expect(existing.order_lines.length).to eq 3

      # Make sure the existing line was not destroyed
      expect { existing_line.reload }.not_to raise_error
    end

    it "doesn't update existing product data if hts stays the same" do
      existing = Factory(:product, importer: ellery, unique_identifier: "ELLERY-15828052084MAR")
      existing.update_hts_for_country(us, "6303922010")

      subject.parse po_csv, bucket: "bucket", key: "path/to/file.csv"

      existing.reload

      expect(existing.entity_snapshots.length).to eq 0
    end

    it "updates hts on existing product if the number changes" do
      existing = Factory(:product, importer: ellery, unique_identifier: "ELLERY-15828052084MAR")
      existing.update_hts_for_country(us, "1234567890")

      subject.parse po_csv, bucket: "bucket", key: "path/to/file.csv"

      existing.reload

      expect(existing.entity_snapshots.length).to eq 1
    end

    it "doesn't update vendor data" do
      vendor = Factory(:vendor, system_code: "ELLERY-BE1220", name: "Existing Vendor")
      subject.parse po_csv, bucket: "bucket", key: "path/to/file.csv"

      vendor.reload 
      expect(vendor.name).to eq "Existing Vendor"
      expect(vendor.addresses.length).to eq 0
    end

    it "doesn't update ship to data" do
      ship_to = Factory(:address, company: ellery, name: "FAYETTEVILLE DC")

      subject.parse po_csv, bucket: "bucket", key: "path/to/file.csv"
      ship_to.reload

      expect(ship_to.line_1).to be_nil
    end

    it "doesn't update if nothing changed" do
      subject.parse po_csv, bucket: "bucket", key: "path/to/file.csv"

      o = Order.where(order_number: "ELLERY-14945").first
      o.entity_snapshots.destroy_all

      subject.parse po_csv, bucket: "bucket", key: "path/to/file.csv"

      o.reload
      expect(o.entity_snapshots.length).to eq 0
    end
  end
end
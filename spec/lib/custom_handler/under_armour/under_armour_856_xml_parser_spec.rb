require "spec_helper"

describe OpenChain::CustomHandler::UnderArmour::UnderArmour856XmlParser do

  let (:data) { IO.read "spec/fixtures/files/ua_856.xml" }
  let (:xml) { REXML::Document.new(data) }
  let (:user) { Factory(:user) }
  let! (:ua) { Factory(:importer, system_code: "UNDAR")}
  let (:product) {
    Factory(:product, importer: ua, unique_identifier: "UNDAR-1242757-001")
  }

  let (:variant) {
    product.variants.create! variant_identifier: "1242757-001-XL"
  }

  let (:order) {
    order = Factory(:order, importer: ua, order_number: "UNDAR-4200001938", customer_order_number: "4200001938")
    line = Factory(:order_line, order: order, product: product, variant: variant, sku: "1242757-001-XL")
    order
  }

  describe "process_shipment" do

    before :each do
      order
    end

    let (:cdefs) { subject.cdefs }

    it "processes 856 xml into a shipment" do
      now = Time.zone.parse "2017-02-03 12:00"
      Timecop.freeze(now) { subject.process_shipment xml, user, "bucket", "file.xml", [] }

      shipment = Shipment.where(reference: "UNDAR-ASN0001045").first
      expect(shipment).not_to be_nil

      expect(shipment.importer_reference).to eq "ASN0001045"
      expect(shipment.booking_number).to eq "6000000556"
      expect(shipment.master_bill_of_lading).to eq "MBOL1938"
      expect(shipment.house_bill_of_lading).to eq "HBOL1938"
      expect(shipment.vessel_carrier_scac).to eq "SCAC"
      expect(shipment.est_delivery_date).to eq Date.new(2016, 12, 18)
      expect(shipment.last_file_bucket).to eq "bucket"
      expect(shipment.last_file_path).to eq "file.xml"
      expect(shipment.last_exported_from_source).to eq now
      expect(shipment.number_of_packages_uom).to eq "CTN"
      expect(shipment.number_of_packages).to eq 2
      expect(shipment.gross_weight).to eq 2
      expect(shipment.volume).to eq 3

      expect(shipment.entity_snapshots.length).to eq 1
      s = shipment.entity_snapshots.first
      expect(s.user).to eq user
      expect(s.context).to eq "file.xml"

      expect(shipment.containers.length).to eq 1
      container = shipment.containers.first
      expect(container.container_number).to eq "MBOL1938"

      expect(shipment.shipment_lines.length).to eq 1

      line = shipment.shipment_lines.first

      expect(line.line_number).to eq 1
      expect(line.container).to eq container
      expect(line.product).to eq product
      expect(line.variant).to eq product.variants.first
      expect(line.quantity).to eq BigDecimal("10")
      expect(line.carton_qty).to eq 2
      # Because of how the XML is set up, this checks the conversion of pounds to KG
      expect(line.gross_kgs).to eq BigDecimal("2")
      # Because of how the XML is set up, this checks the conversion of centimeters to meters
      expect(line.cbms).to eq BigDecimal("3")
      expect(line.custom_value(cdefs[:shpln_coo])).to eq "VN"
      expect(line.piece_sets.first.order_line).to eq order.order_lines.first
      expect(line.piece_sets.first.quantity).to eq BigDecimal("10")
    end

    it "updates a shipment" do
      shipment = Factory(:shipment, importer: ua, reference: "UNDAR-ASN0001045")
      line = shipment.shipment_lines.create! line_number: 1, product: product
      container = shipment.containers.create! container_number: "MBOL1938"

      subject.process_shipment xml, user, "bucket", "file.xml", []

      shipment.reload

      # just check that something was loaded/saved and that the old line was destroyed
      expect(shipment.entity_snapshots.length).to eq 1

      expect { line.reload }.to raise_error ActiveRecord::RecordNotFound
      expect { container.reload }.not_to raise_error

      expect(shipment.shipment_lines.length).to eq 1
    end

    context "error handling" do
      let(:errors) { [] }

      it "appends error if trailer is blank" do
        data.gsub!("<Trailer>MBOL1938</Trailer>", "<Trailer></Trailer>")
        subject.process_shipment xml, user, "bucket", "file.xml", errors
        expect(errors).to eq ["IBD # 6000000556 / ASN # ASN0001045: No container number value found in 'Trailer' element."]
      end

      it "appends error if po couldn't be found" do
        order.destroy
        subject.process_shipment xml, user, "bucket", "file.xml", errors
        expect(errors).to eq ["IBD # 6000000556 / ASN # ASN0001045: Failed to find Order # 4200001938."]
      end

      it "appends error if order line couldn't be found" do
        order.order_lines.destroy_all
        subject.process_shipment xml, user, "bucket", "file.xml", errors
        expect(errors).to eq ["IBD # 6000000556 / ASN # ASN0001045: Failed to find SKU 1242757-001-XL on Order 4200001938."]
      end
    end

    it "doesn't destroy existing lines if 'UA EEM Conversion' custom feature is enabled" do
      ms = stub_master_setup
      expect(ms).to receive(:custom_feature?).with("UA EEM Conversion").and_return true

      shipment = Factory(:shipment, importer: ua, reference: "UNDAR-ASN0001045")
      line = shipment.shipment_lines.create! line_number: 1, product: product
      container = shipment.containers.create! container_number: "MBOL1938"

      subject.process_shipment xml, user, "bucket", "file.xml", []

      shipment.reload

      expect { line.reload }.not_to raise_error
      expect(shipment.shipment_lines.length).to eq 2
    end
  end

  describe "send_error_email" do
    let(:error) {
      ["ERROR"]
    }
    
    it "writes XML to file and emails to edi support" do
      subject.send_error_email "<xml></xml>", "file.xml", error

      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first

      expect(m.to).to eq ["edisupport@vandegriftinc.com"]
      expect(m.subject).to eq "Under Armour Shipment XML Processing Error"
      expect(m.body.raw_source).to include "ERROR"
      expect(m.attachments["file.xml"]).not_to be_nil
      expect(m.attachments["file.xml"].read).to eq "<xml></xml>"
    end
  end
  
  describe "integration_folder" do
    subject { described_class }

    it "uses the correct folder" do
      expect(subject.integration_folder).to eq "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ua_856_xml"
    end
  end

  describe "parse" do
    subject { described_class }

    it "parses xml string" do
      order
      subject.parse data, bucket: "bucket", key: "file.xml"

      expect(Shipment.where(reference: "UNDAR-ASN0001045").first).not_to be_nil
    end

    it "emails error without parsing if importer isn't set up" do
      ua.destroy
      expect_any_instance_of(subject).to receive(:send_error_email).with(data, "file.xml", ["Unable to find Under Armour 'UNDAR' importer account."])
      expect_any_instance_of(subject).to_not receive(:process_shipment)
      subject.parse data, bucket: "bucket", key: "file.xml"
    end
  end
end
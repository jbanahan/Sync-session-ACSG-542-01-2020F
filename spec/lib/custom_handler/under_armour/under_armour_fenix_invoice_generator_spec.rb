require 'spec_helper'

describe OpenChain::CustomHandler::UnderArmour::UnderArmourFenixInvoiceGenerator do

  describe "generate_invoice" do
    let (:cdefs) { subject.send(:cdefs) }
    let (:ca) { Factory(:country, iso_code: "CA") }
    let (:importer) { Factory(:importer, system_code: "UNDAR", name: "Under Armour")}
    let (:shipment) {
      s = Factory(:shipment, importer: importer, importer_reference: "REF")
      line = s.shipment_lines.create! quantity: 10, product: standard_product, variant: standard_product.variants.first, carton_qty: 2, gross_kgs: 8
      line.update_custom_value!(cdefs[:shpln_coo], "CN")
      line.piece_sets.create! quantity: 10, order_line: order.order_lines.first

      line = s.shipment_lines.create! quantity: 20, product: variant_hts_product, variant: variant_hts_product.variants.first, carton_qty: 1, gross_kgs: 2
      line.update_custom_value!(cdefs[:shpln_coo], "VN")
      line.piece_sets.create! quantity: 20, order_line: order.order_lines.second

      s
    }

    let (:variant_hts_product) {
      p = Factory(:product, importer: importer, unique_identifier: "UNDAR-PROD-1", name: "Name Description 1")
      p.update_custom_value! cdefs[:prod_part_number], "PROD-1"
      c = p.classifications.create! country_id: ca.id
      t = c.tariff_records.create! hts_1: "1234567890"
      v = p.variants.create! variant_identifier: "PROD-1-XS"
      v.update_custom_value! cdefs[:var_hts_code], "9876543210"

      p
    }

    let (:standard_product) {
      p = Factory(:product, importer: importer, unique_identifier: "UNDAR-PROD-2", name: "Name Description 2")
      p.update_custom_value! cdefs[:prod_part_number], "PROD-2"
      c = p.classifications.create! country_id: ca.id
      c.update_custom_value! cdefs[:class_customs_description], "Customs Description 2"
      t = c.tariff_records.create! hts_1: "1234567890"
      v = p.variants.create! variant_identifier: "PROD-2-XL"

      p
    }

    let (:copy_product) {
      p = Factory(:product, importer: importer, unique_identifier: "UNDAR-PROD-3", name: "Name Description 2")
      p.update_custom_value! cdefs[:prod_part_number], "PROD-2"
      c = p.classifications.create! country_id: ca.id
      c.update_custom_value! cdefs[:class_customs_description], "Customs Description 2"
      t = c.tariff_records.create! hts_1: "1234567890"
      v = p.variants.create! variant_identifier: "PROD-2-XL"

      p
    }

    let (:order) {
      order = Factory(:order, order_number: "UNDAR-PO", customer_order_number: "PO")
      line1 = order.order_lines.create! product: standard_product, variant: standard_product.variants.first, price_per_unit: BigDecimal("1.55")
      line2 = order.order_lines.create! product: variant_hts_product, variant: variant_hts_product.variants.first, price_per_unit: BigDecimal("1.99")
      # Make a 3rd line which can be utilized for roll-up scenarios
      line3 = order.order_lines.create! product: copy_product, variant: copy_product.variants.first, price_per_unit: BigDecimal("1.55")

      order
    }

    it "generates commercial invoice object" do
      now = Time.zone.parse("2017-02-06 02:00")
      inv = nil
      Timecop.freeze(now) do 
        inv = subject.generate_invoice shipment
      end
      
      expect(inv.invoice_number).to eq "REF"
      expect(inv.invoice_date).to eq Date.new(2017, 2, 5)
      expect(inv.importer).to eq importer
      expect(inv.total_quantity_uom).to eq "CTN"
      expect(inv.total_quantity).to eq 3
      expect(inv.gross_weight).to eq 10
      expect(inv.currency).to eq "USD"

      expect(inv.commercial_invoice_lines.length).to eq 2

      line = inv.commercial_invoice_lines.first

      expect(line.part_number).to eq "PROD-2"
      expect(line.country_origin_code).to eq "CN"
      expect(line.quantity).to eq 10
      expect(line.unit_price).to eq BigDecimal("1.55")
      expect(line.po_number).to eq "PO"
      expect(line.customer_reference).to eq "REF"

      expect(line.commercial_invoice_tariffs.length).to eq 1
      t = line.commercial_invoice_tariffs.first
      expect(t.hts_code).to eq "1234567890"
      expect(t.tariff_description).to eq "Customs Description 2"


      # Some of this line's data comes from the variant's data and an alternate location for the description
      line = inv.commercial_invoice_lines.second

      expect(line.part_number).to eq "PROD-1"
      expect(line.country_origin_code).to eq "VN"
      expect(line.quantity).to eq 20
      expect(line.unit_price).to eq BigDecimal("1.99")
      expect(line.po_number).to eq "PO"
      expect(line.customer_reference).to eq "REF"

      expect(line.commercial_invoice_tariffs.length).to eq 1
      t = line.commercial_invoice_tariffs.first
      expect(t.hts_code).to eq "9876543210"
      expect(t.tariff_description).to eq "Name Description 1"
    end

    context "with rollable lines" do
      before :each do 
        line = shipment.shipment_lines.second
        line.product = copy_product
        line.variant = copy_product.variants.first
        line.save!

        line.update_custom_value!(cdefs[:shpln_coo], "CN")
        line.piece_sets.destroy_all
        line.piece_sets.create! quantity: 10, order_line: order.order_lines[2]
      end

      it "combines lines together by PO, Style, COO, Tariff, Unit Price" do
        inv = subject.generate_invoice shipment

        expect(inv.commercial_invoice_lines.length).to eq 1
        line = inv.commercial_invoice_lines.first

        expect(line.part_number).to eq "PROD-2"
        expect(line.country_origin_code).to eq "CN"
        expect(line.quantity).to eq 30
        expect(line.unit_price).to eq BigDecimal("1.55")
        expect(line.po_number).to eq "PO"
        expect(line.customer_reference).to eq "REF"

        expect(line.commercial_invoice_tariffs.length).to eq 1
        t = line.commercial_invoice_tariffs.first
        expect(t.hts_code).to eq "1234567890"
        expect(t.tariff_description).to eq "Customs Description 2"
      end

      it "does not roll up if the unit price is different" do
        order.order_lines[2].update_attributes! price_per_unit: BigDecimal("2.00")

        inv = subject.generate_invoice shipment
        expect(inv.commercial_invoice_lines.length).to eq 2
      end

      it "does not roll up if the country of origin is different" do
        shipment.shipment_lines.second.update_custom_value! cdefs[:shpln_coo], "VN"

        inv = subject.generate_invoice shipment
        expect(inv.commercial_invoice_lines.length).to eq 2
      end

      it "does not roll up if the hts is different" do
        copy_product.classifications.first.tariff_records.first.update_attributes! hts_1: "6666666666"
        shipment.reload
        inv = subject.generate_invoice shipment
        expect(inv.commercial_invoice_lines.length).to eq 2
      end

      it "does not roll up if the style is different" do
        copy_product.update_custom_value! cdefs[:prod_part_number], "STYLE 3"

        inv = subject.generate_invoice shipment
        expect(inv.commercial_invoice_lines.length).to eq 2
      end

      it "does not roll up if the PO # is different" do
        copy_order = Factory(:order, order_number: "UNDAR-PO2", customer_order_number: "PO2")
        line = copy_order.order_lines.create! product: standard_product, variant: standard_product.variants.first, price_per_unit: BigDecimal("1.55")

        s_line = shipment.shipment_lines.first
        s_line.piece_sets.destroy_all
        s_line.piece_sets.create! quantity: 10, order_line: line

        inv = subject.generate_invoice shipment
        expect(inv.commercial_invoice_lines.length).to eq 2
      end

      it "explodes prepack values and rolls them up" do
        copy_product.update_custom_value! cdefs[:prod_prepack], true

        # Just add a second variant. This will end up exploading to 2 lines - 
        # The first variant should get rolled together with the first shipment line, the second 
        # should produce a second invoice line
        copy_product.variants.create! variant_identifier: "PROD-3-XL"
        copy_product.variants.first.update_custom_value! cdefs[:var_units_per_inner_pack], 5
        copy_product.variants.second.update_custom_value! cdefs[:var_units_per_inner_pack], 10

        shipment.reload
        inv = subject.generate_invoice shipment
        expect(inv.commercial_invoice_lines.length).to eq 2

        # Just validate all the fields so we know the prepack lines are exploding using the data we expect
        # them to
        line = inv.commercial_invoice_lines.first


        expect(line.part_number).to eq "PROD-2"
        expect(line.country_origin_code).to eq "CN"
        expect(line.quantity).to eq 110
        expect(line.unit_price).to eq BigDecimal("1.55")
        expect(line.po_number).to eq "PO"
        expect(line.customer_reference).to eq "REF"

        expect(line.commercial_invoice_tariffs.length).to eq 1
        t = line.commercial_invoice_tariffs.first
        expect(t.hts_code).to eq "1234567890"
        expect(t.tariff_description).to eq "Customs Description 2"

        line = inv.commercial_invoice_lines.second

        expect(line.part_number).to eq "PROD-3"
        expect(line.country_origin_code).to eq "CN"
        expect(line.quantity).to eq 200
        expect(line.unit_price).to eq BigDecimal("1.55")
        expect(line.po_number).to eq "PO"
        expect(line.customer_reference).to eq "REF"

        expect(line.commercial_invoice_tariffs.length).to eq 1
        t = line.commercial_invoice_tariffs.first
        expect(t.hts_code).to eq "1234567890"
        expect(t.tariff_description).to eq "Customs Description 2"
      end
    end
  end

  describe "generate_and_send" do

    it "generates an invoice and sends it via fenix nd generator" do
      shipment = instance_double(Shipment)
      invoice = instance_double(CommercialInvoice)
      expect(subject).to receive(:generate_invoice).with(shipment).and_return invoice
      expect(subject).to receive(:generate_and_send).with(invoice)

      subject.generate_and_send_invoice shipment
    end
  end

  describe "ftp_folder" do
    it "uses the correct folder" do
      expect(subject.ftp_folder).to eq "to_ecs/fenix_invoices/UNDERARM"
    end
  end
end
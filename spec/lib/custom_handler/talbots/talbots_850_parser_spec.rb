describe OpenChain::CustomHandler::Talbots::Talbots850Parser do
  let (:standard_data) { IO.read 'spec/fixtures/files/talbots.edi' }
  let (:prepack_data) { IO.read 'spec/fixtures/files/talbots_prepack.edi'}
  let (:cdefs) { described_class.new.cdefs }
  let! (:talbots) { Factory(:importer, system_code: "Talbots") }
  let! (:us) { Factory(:country, iso_code: "US") }

  before(:all) {
    described_class.new.cdefs
  }

  after(:all) {
    CustomDefinition.destroy_all
  }

  describe "parse", :disable_delayed_jobs do 
    
    let! (:ai) { Factory(:country, iso_code: "AI")}
    let! (:cn) { Factory(:country, iso_code: "CN")}

    subject { described_class }

    it "creates an order from standard order type" do 
      subject.parse standard_data, bucket: "bucket", key: "talbots.edi"
      order = Order.where(order_number: "Talbots-5086819").first

      expect(order).not_to be_nil
      expect(order.last_exported_from_source).to eq ActiveSupport::TimeZone["America/New_York"].parse "201508042223"
      expect(order.last_file_bucket).to eq "bucket"
      expect(order.last_file_path).to eq "talbots.edi"

      expect(order.customer_order_number).to eq "5086819"
      expect(order.order_date).to eq Date.new(2015, 2, 2)
      expect(order.terms_of_payment).to eq "PP"
      expect(order.terms_of_sale).to eq "CPT Mod. Incoterms 2010"
      expect(order.mode).to eq "Boat"
      expect(order.season).to eq "Season"

      expect(order.custom_value(cdefs[:ord_type])).to eq "SA"
      expect(order.custom_value(cdefs[:ord_country_of_origin])).to eq "CHINA"
      expect(order.custom_value(cdefs[:ord_buyer])).to eq "TB9LXM"
      expect(order.custom_value(cdefs[:ord_buyer_order_number])).to eq "30006927"

      expect(order.ship_window_start).to eq Date.new(2015, 8, 24)
      expect(order.ship_window_end).to eq Date.new(2015, 8, 24)
      expect(order.first_expected_delivery_date).to eq Date.new(2015, 9, 4)
      expect(order.entity_snapshots.length).to eq 1
      s = order.entity_snapshots.first
      expect(s.user).to eq User.integration
      expect(s.context).to eq "talbots.edi"

      vendor = order.vendor
      expect(vendor).not_to be_nil
      expect(vendor.system_code).to eq "Talbots-00131755"
      expect(vendor.name).to eq "RED & BLUE INTERNATIONAL"
      address = vendor.addresses.first
      expect(address.line_1).to eq "THE HALLMARK BLDG SUITE 227"
      expect(address.line_2).to eq "OLD AIRPORT RD"
      expect(address.city).to eq "ANGUILLA"
      expect(address.state).to eq "BWI"
      expect(address.postal_code).to eq "12345"
      expect(address.country).to eq ai
      expect(talbots.linked_companies).to include vendor

      factory = order.factory
      expect(factory).not_to be_nil
      expect(factory.system_code).to eq "Talbots-CNZHOHEQ6ZHO"
      expect(factory.name).to eq "ZHONGSHAN HEQING GARMENT & LAUNDRY CO LTD"
      expect(factory.mid).to eq "CNZHOHEQ6ZHO"
      address = factory.addresses.first
      expect(address.line_1).to eq "FID CN5010"
      expect(address.line_2).to eq "NO 6 GAOPING INDUSTRY AREA SANJIAO TOWN"
      expect(address.city).to eq "ZHONGSHAN CITY"
      expect(address.state).to eq "GU"
      expect(address.postal_code).to eq "528445"
      expect(address.country).to eq cn
      expect(talbots.linked_companies).to include factory
      expect(vendor.linked_companies).to include factory

      ship_to = order.ship_to
      expect(ship_to).not_to be_nil
      expect(ship_to.name).to eq "The Talbots Inc"
      expect(ship_to.system_code).to eq "0080"
      expect(ship_to.line_1).to eq "1 TALBOTS WAY"
      expect(ship_to.city).to eq "LAKEVILLE"
      expect(ship_to.state).to eq "MA"
      expect(ship_to.postal_code).to eq "02348"
      expect(ship_to.country).to eq us

      product = Product.where(unique_identifier: "Talbots-53903309P/FL15").first
      expect(product).not_to be_nil
      expect(product.importer).to eq talbots
      expect(product.name).to eq "C SLIMMING 5PKT BOOT DNM - DUSK WASH"
      expect(product.custom_value(cdefs[:prod_part_number])).to eq "53903309P/FL15"
      expect(product.custom_value(cdefs[:prod_fabric_content])).to eq "99% COTTON 1% SPANDEX"
      expect(product.custom_value(cdefs[:prod_fish_wildlife])).to eq true

      expect(product.hts_for_country(us)).to eq ["6204624011"]

      expect(product.variants.length).to eq 2

      variant1 = product.variants.find {|v| v.variant_identifier == "41013798"}
      expect(variant1).not_to be_nil
      expect(variant1.custom_value(cdefs[:var_hts_code])).to eq "6204624011"
      expect(variant1.custom_value(cdefs[:var_color])).to eq "3-DUSK WASH-HVY SUPE"
      expect(variant1.custom_value(cdefs[:var_size])).to eq "040"

      variant2 = product.variants.find {|v| v.variant_identifier == "41014523"}
      expect(variant2).not_to be_nil
      expect(variant2.custom_value(cdefs[:var_hts_code])).to eq "6204624011"
      expect(variant2.custom_value(cdefs[:var_color])).to eq "3-DUSK WASH-HVY SUPE"
      expect(variant2.custom_value(cdefs[:var_size])).to eq "060"
      
      expect(product.entity_snapshots.length).to eq 1
      s = product.entity_snapshots.first
      expect(s.context).to eq "talbots.edi"
      expect(s.user).to eq User.integration

      expect(order.order_lines.length).to eq 2
      line = order.order_lines.first

      expect(line.line_number).to eq 1
      expect(line.product).to eq product
      expect(line.variant).to eq variant1
      expect(line.unit_of_measure).to eq "EA"
      expect(line.price_per_unit).to eq BigDecimal("12.03")
      expect(line.sku).to eq "41013798"
      expect(line.hts).to eq "6204624011"
      expect(line.custom_value(cdefs[:ord_line_buyer_item_number])).to eq "275706"
      expect(line.custom_value(cdefs[:ord_line_color])).to eq "3-DUSK WASH-HVY SUPE"
      expect(line.custom_value(cdefs[:ord_line_size])).to eq "040"
      expect(line.custom_value(cdefs[:ord_line_size_description])).to eq "4P"
      expect(line.quantity).to eq BigDecimal("24")

      line = order.order_lines.second
      expect(line.line_number).to eq 2
      expect(line.product).to eq product
      expect(line.variant).to eq variant2
      expect(line.unit_of_measure).to eq "EA"
      expect(line.price_per_unit).to eq BigDecimal("12.05")
      expect(line.sku).to eq "41014523"
      expect(line.hts).to eq "6204624011"
      expect(line.custom_value(cdefs[:ord_line_buyer_item_number])).to eq "275706"
      expect(line.custom_value(cdefs[:ord_line_color])).to eq "3-DUSK WASH-HVY SUPE"
      expect(line.custom_value(cdefs[:ord_line_size])).to eq "060"
      expect(line.custom_value(cdefs[:ord_line_size_description])).to eq "6P"
      expect(line.quantity).to eq BigDecimal("11")
    end

    it "creates an order from prepack order type" do 
      subject.parse prepack_data, bucket: "bucket", key: "talbots.edi"
      order = Order.where(order_number: "Talbots-5086819").first

      expect(order).not_to be_nil

      # The only real difference in data here should be the way the quantity on the line is calculated
      expect(order.custom_value(cdefs[:ord_type])).to eq "OS"
      expect(order.order_lines.length).to eq 2

      product = Product.where(unique_identifier: "Talbots-53903309P/FL15").first
      expect(product).not_to be_nil

      variant1 = product.variants.find {|v| v.variant_identifier == "41013798"}
      variant2 = product.variants.find {|v| v.variant_identifier == "41014523"}

      line = order.order_lines.first
      expect(line.quantity).to eq 32
      expect(line.product).to eq product
      expect(line.variant).to eq variant1

      line = order.order_lines.second
      expect(line.quantity).to eq 33
      expect(line.product).to eq product
      expect(line.variant).to eq variant2
    end

    context "with existing data" do
      let (:product) {
        Factory(:product, importer:talbots, unique_identifier: "Talbots-53903309P/FL15")
      }

      let (:order) {
        order = Factory(:order, importer: talbots, order_number: "Talbots-5086819")
      }

      let! (:order_line) {
        Factory(:order_line, order: order, product: product, line_number: 1, sku: "sku")
      }

      it "updates an existing order, deleting all existing lines" do
        subject.parse standard_data, bucket: "bucket", key: "talbots.edi"

        order.reload
        expect(order.order_lines.length).to eq 2
        # If the exisitng order line was removed, then it will raise an error trying to reload it
        expect { order_line.reload }.to raise_error ActiveRecord::RecordNotFound
      end
    end
  end


  describe "update_standard_product" do
    let (:edi_segments) {
      REX12::Document.each_transaction(standard_data) { |t| return t.segments }
    }

    let (:po1_segment) {
      subject.find_segment(edi_segments, "PO1")
    }

    let (:product) {
      product = Factory(:product, importer: talbots, unique_identifier: "Talbots-53903309P/FL15", name: "C SLIMMING 5PKT BOOT DNM - DUSK WASH")
      product.update_custom_value! cdefs[:prod_fish_wildlife], true
      product.update_custom_value! cdefs[:prod_fabric_content], "99% COTTON 1% SPANDEX"
      product.update_hts_for_country(us, "6204624011")

      variant = product.variants.create! variant_identifier: "41013798"
      variant.update_custom_value! cdefs[:var_hts_code], "6204624011"
      variant.update_custom_value! cdefs[:var_color], "3-DUSK WASH-HVY SUPE"
      variant.update_custom_value! cdefs[:var_size], "040"

      variant = product.variants.create! variant_identifier: "41014523"
      variant.update_custom_value! cdefs[:var_hts_code], "6204624011"
      variant.update_custom_value! cdefs[:var_color], "3-DUSK WASH-HVY SUPE"
      variant.update_custom_value! cdefs[:var_size], "060"

      # Reload is needed otherwise the product/variant is already marked as changed
      product.reload
    }

    it "returns false if data is not updated" do
      expect(subject.update_standard_product product, edi_segments, po1_segment, []).to eq false
    end

    it "returns true if Fish / Wildlife changes" do
      product.update_custom_value! cdefs[:prod_fish_wildlife], false
      expect(subject.update_standard_product product.reload, edi_segments, po1_segment, []).to eq true
    end

    it "returns true if Fabric Content changes" do
      product.update_custom_value! cdefs[:prod_fabric_content], "100% Cotton"
      expect(subject.update_standard_product product.reload, edi_segments, po1_segment, []).to eq true
    end

    it "returns true if Description changes" do
      product.update_attributes! name: "Name"
      expect(subject.update_standard_product product.reload, edi_segments, po1_segment, []).to eq true
    end

    it "returns true if HTS changes" do
      product.update_hts_for_country us, "12345567890"
      expect(subject.update_standard_product product.reload, edi_segments, po1_segment, []).to eq true
    end

    it "returns true if new variant added" do
      product.variants.first.destroy
      expect(subject.update_standard_product product.reload, edi_segments, po1_segment, []).to eq true
    end

    it "returns true if variant color updated" do
      product.variants.first.update_custom_value! cdefs[:var_color], "Color"
      expect(subject.update_standard_product product.reload, edi_segments, po1_segment, []).to eq true
    end

    it "returns true if variant size updated" do
      product.variants.first.update_custom_value! cdefs[:var_size], "Small"
      expect(subject.update_standard_product product.reload, edi_segments, po1_segment, []).to eq true
    end
  end
end
describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderCreatedDataRecorder do

  before :all do
    described_class.new.send(:cdefs)
  end

  after :all do
    CustomDefinition.destroy_all
  end

  let (:cdefs) {
    subject.send(:cdefs)
  }

  let (:new_snapshot) {
    {
      "entity" => {
        "core_module" => "Order",
        "model_fields" => {
          "ord_ord_num" => "4500230506",
          cdefs[:ord_country_of_origin].model_field_uid => "CN"
        },
        "children" => [
          {
            "entity" => {
              "core_module" => "OrderLine",
              "model_fields" => {
                "ordln_line_number" => 1,
                "ordln_ordered_qty" => "30234.6",
                "ordln_ppu" => "0.7",
                "ordln_total_cost" => "21164.22",
                "ordln_puid" => "000000000010044298"
              }
            }
          }
        ]
      }
    }
  }

  let (:us) {
    Country.create! iso_code: "US"
  }

  let (:product) {
    p = Product.create! unique_identifier: "000000000010044298"
    p.update_hts_for_country us, "1234567890"
    p
  }

  let (:order) {
    order = Order.create! order_number: "4500230506", importer_id: FactoryBot(:importer).id
    # Don't set anything that's not required, we want to ensure the data that's set comes from the
    # snapshot data.
    order.order_lines.create! line_number: 1, product_id: product.id
    order
  }

  describe "record_data" do
    it "records core order line data to order line and returns true if lines added" do
      expect(subject.record_data order, nil, new_snapshot).to eq true

      order.reload
      line = order.order_lines.first
      expect(line.custom_value(cdefs[:ordln_po_create_article])).to eq "000000000010044298"
      expect(line.custom_value(cdefs[:ordln_po_create_quantity])).to eq BigDecimal("30234.6")
      expect(line.custom_value(cdefs[:ordln_po_create_hts])).to eq "1234567890"
      expect(line.custom_value(cdefs[:ordln_po_create_price_per_unit])).to eq BigDecimal("0.7")
      expect(line.custom_value(cdefs[:ordln_po_create_total_price])).to eq BigDecimal("21164.22")
      expect(line.custom_value(cdefs[:ordln_po_create_country_origin])).to eq "CN"
    end

    it "does nothing and returns false if no lines added" do
      expect(subject.record_data order, new_snapshot, new_snapshot).to eq false
    end
  end


end
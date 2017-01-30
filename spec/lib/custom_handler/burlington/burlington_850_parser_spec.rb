describe OpenChain::CustomHandler::Burlington::Burlington850Parser do

  let (:standard_edi) { IO.read 'spec/fixtures/files/burlington_850_standard.edi' }
  let (:prepack_edi) { IO.read 'spec/fixtures/files/burlington_850_prepack.edi' }

  before(:all) { described_class.new.cdefs }
  after(:all) { CustomDefinition.destroy_all }

  describe "parse" do
    subject { described_class }
    let! (:burlington) { Factory(:importer, system_code: "BURLI", name: "Burlington") }
    let! (:us) { Factory(:country, iso_code: "US") }

    let (:cdefs) { subject.new.cdefs }
    let (:existing_order) { Factory(:order, importer: burlington, order_number: "BURLI-364225101")}
    let (:existing_product) { Factory(:product, importer: burlington, unique_identifier: "BURLI-9050-E", name: "PARIS CRIB N CHANGER")}
    let (:existing_prepack_product) { 
      p = Factory(:product, importer: burlington, unique_identifier: "BURLI-10708", name: "BEADOS S4 4 COLOR PEN")
      c = p.classifications.create! country: us
      c.tariff_records.create! hts_1: "9503000073"
      p
    }

    it "processes standard edi, creating products and order" do
      now = Time.zone.now
      Timecop.freeze(now) do
        subject.parse standard_edi, bucket: "bucket", key: "file.edi"
      end

      order = Order.where(order_number: "BURLI-364225101").first
      expect(order).not_to be_nil
      expect(order.customer_order_number).to eq "364225101"
      expect(order.importer).to eq burlington
      expect(order.order_date).to eq Date.new(2016, 9, 2)
      expect(order.terms_of_payment).to eq "CC"
      expect(order.terms_of_sale).to eq "FOB"
      expect(order.ship_window_start).to eq Date.new(2016, 9, 5)
      expect(order.ship_window_end).to eq Date.new(2016, 9, 12)
      expect(order.mode).to eq "Containerized Ocean"
      expect(order.custom_value(cdefs[:ord_revision])).to eq 2
      expect(order.custom_value(cdefs[:ord_revision_date])).to eq now.in_time_zone("America/New_York").to_date
      expect(order.custom_value(cdefs[:ord_type])).to eq "SA"
      expect(order.custom_value(cdefs[:ord_planned_forwarder])).to eq "Mmmmmmm Orient Logistics"
      expect(order.last_file_path).to eq "file.edi"
      expect(order.last_file_bucket).to eq "bucket"
      expect(order.entity_snapshots.length).to eq 1
      expect(order.entity_snapshots.first.context).to eq "file.edi"
      expect(order.entity_snapshots.first.user).to eq User.integration

      expect(order.order_lines.length).to eq 1

      line = order.order_lines.first
      expect(line.line_number).to eq 1
      expect(line.quantity).to eq BigDecimal("436")
      expect(line.unit_of_measure).to eq "EA"
      expect(line.price_per_unit).to eq BigDecimal("124")
      expect(line.hts).to eq "9403.50.9041"
      expect(line.custom_value(cdefs[:ord_line_department_code])).to eq "Kids"
      expect(line.custom_value(cdefs[:ord_line_size])).to eq "QTY"
      expect(line.custom_value(cdefs[:ord_line_color])).to eq "ESPRESSO"
      expect(line.custom_value(cdefs[:ord_line_estimated_unit_landing_cost])).to eq BigDecimal("131.88")
      expect(line.custom_value(cdefs[:ord_line_retail_unit_price])).to eq BigDecimal("199.99")

      p = line.product
      expect(p.unique_identifier).to eq "BURLI-9050-E"
      expect(p.classifications.length).to eq 1
      expect(p.classifications.first.tariff_records.length).to eq 1
      t = p.classifications.first.tariff_records.first
      expect(t.line_number).to eq 1
      expect(t.hts_1).to eq "9403509041"

      expect(p.entity_snapshots.length).to eq 1
      expect(p.entity_snapshots.first.context).to eq "file.edi"
      expect(p.entity_snapshots.first.user).to eq User.integration
    end

    it "updates existing orders, deleting any line not referenced in new order" do
      ol = existing_order.order_lines.create! line_number: 2, product: existing_product

      subject.parse standard_edi, bucket: "bucket", key: "file.edi"

      existing_order.reload
      expect(existing_order).not_to be_nil
      expect(existing_order.order_lines.length).to eq 1
      expect(existing_order.order_lines.first.line_number).to eq 1
      # Also check that the product was re-used
      p = existing_order.order_lines.first.product
      expect(p).to eq existing_product

      # Since it was changed, it should have had a snapshot too
      expect(p.entity_snapshots.length).to eq 1

      expect { ol.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it "updates existing orders, deleting existing lines and replacing them" do
      ol = existing_order.order_lines.create! line_number: 1, product: existing_product

      subject.parse standard_edi, bucket: "bucket", key: "file.edi"

      existing_order.reload
      expect(existing_order).not_to be_nil
      expect(existing_order.order_lines.length).to eq 1
      expect(existing_order.order_lines.first.line_number).to eq 1

      expect { ol.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it "ignores lines that are shipping and does not update them" do
      ol = existing_order.order_lines.create! line_number: 1, product: existing_product
      sl = Factory(:shipment_line, shipment: Factory(:shipment, reference: "REF"), product: ol.product)
      PieceSet.create!(quantity: 1, order_line: ol, shipment_line: sl)

      subject.parse standard_edi, bucket: "bucket", key: "file.edi"

      existing_order.reload
      expect(existing_order).not_to be_nil
      expect(existing_order.order_lines.length).to eq 1
      expect(existing_order.order_lines.first).to eq ol

      # Just make sure no data from the edi was added to the line (any value that we expect to be set shouldn't be there.)
      expect(ol.unit_of_measure).to be_nil
    end

    it "does not snapshot products that haven't changed" do
      c = existing_product.classifications.create! country: us
      t = c.tariff_records.create! hts_1: "9403509041"

      subject.parse standard_edi, bucket: "bucket", key: "file.edi"

      existing_product.reload
      expect(existing_product.entity_snapshots.length).to eq 0
    end

    it "parses edi with prepack lines" do
      subject.parse prepack_edi, bucket: "bucket", key: "file.edi"

      order = Order.where(order_number: "BURLI-364225101").first
      expect(order).not_to be_nil

      # Nothing is different at the order header for prepacks, so don't worry about checking anything
      expect(order.order_lines.length).to eq 2

      line = order.order_lines.first
      expect(line.line_number).to eq 1001
      expect(line.quantity).to eq BigDecimal("716")
      expect(line.hts).to eq "9503.00.0073"
      expect(line.price_per_unit).to eq BigDecimal("7")
      expect(line.custom_value(cdefs[:ord_line_department_code])).to eq "Kids"
      expect(line.custom_value(cdefs[:ord_line_size])).to eq "QTY"
      expect(line.custom_value(cdefs[:ord_line_color])).to eq "BEADOS"
      expect(line.custom_value(cdefs[:ord_line_estimated_unit_landing_cost])).to eq BigDecimal("7.37")
      expect(line.custom_value(cdefs[:ord_line_retail_unit_price])).to eq BigDecimal("10.99")
      expect(line.custom_value(cdefs[:ord_line_prepacks_ordered])).to eq BigDecimal("179")
      expect(line.custom_value(cdefs[:ord_line_units_per_inner_pack])).to eq BigDecimal("4")

      # I copy/pasted a second line into the EDI...so everything (except color) will be literally the 
      # same values...so just check that the line numbes are as expected
      line = order.order_lines.second
      expect(line.line_number).to eq 1002
      expect(line.custom_value(cdefs[:ord_line_color])).to eq "RED"

      # Now, make sure the product was created 
      p = line.product
      expect(p.entity_snapshots.length).to eq 1
    end

    it "updates orders with existing prepack lines" do
      ol = existing_order.order_lines.create line_number: 1001, product: existing_prepack_product

      subject.parse prepack_edi, bucket: "bucket", key: "file.edi"

      order = Order.where(order_number: "BURLI-364225101").first
      expect(order).not_to be_nil

      # Nothing is different at the order header for prepacks, so don't worry about checking anything
      expect(order.order_lines.length).to eq 2

      line = order.order_lines.first
      expect(line).not_to eq ol
      expect(line.line_number).to eq 1001
      expect(line.product).to eq existing_prepack_product

      expect {ol.reload}.to raise_error ActiveRecord::RecordNotFound

      line = order.order_lines.second
      expect(line.line_number).to eq 1002
      expect(line.product).to eq existing_prepack_product

      # Make sure no snapshot was made for the product
      expect(existing_prepack_product.entity_snapshots.length).to eq 0

      # Make sure an order snapshot was made
      expect(order.entity_snapshots.length).to eq 1
    end

    it "cancels orders" do
      now = Time.zone.now
      Timecop.freeze(now) do
        subject.parse standard_edi.sub("BEG|05|", "BEG|01|"), bucket: "bucket", key: "file.edi"
      end

      order = Order.where(order_number: "BURLI-364225101").first
      expect(order).not_to be_nil
      expect(order.closed_at.to_i).to eq now.to_i
      expect(order.closed_by).to eq User.integration
      expect(order.customer_order_number).to eq "364225101"
      expect(order.importer).to eq burlington
      expect(order.custom_value(cdefs[:ord_revision])).to eq 2
      expect(order.custom_value(cdefs[:ord_revision_date])).to eq now.in_time_zone("America/New_York").to_date
      expect(order.last_file_path).to eq "file.edi"
      expect(order.last_file_bucket).to eq "bucket"

      expect(order.entity_snapshots.length).to eq 1
      expect(order.entity_snapshots.first.context).to eq "file.edi"
      expect(order.entity_snapshots.first.user).to eq User.integration

      # There should be no lines because on a cancellation, all we do is mark it closed and stop processing
      expect(order.order_lines.length).to eq 0
    end

    it "re-opens orders" do
      existing_order.update_attributes! closed_at: Time.zone.now, closed_by: User.integration
      ol = existing_order.order_lines.create! line_number: 2, product: existing_product

      subject.parse standard_edi, bucket: "bucket", key: "file.edi"

      existing_order.reload
      expect(existing_order).not_to be_nil
      expect(existing_order.closed_at).to be_nil
      expect(existing_order.closed_by).to be_nil
      expect(existing_order.order_lines.length).to eq 1
      expect(existing_order.order_lines.first.line_number).to eq 1

      expect { ol.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it "handles errors" do
      expect_any_instance_of(subject).to receive(:process_order).and_raise StandardError, "Testing"
      expect(subject).to receive(:send_error_email) do |transaction, error, parser, filename|
        expect(transaction).to be_a(REX12::Transaction)
        expect(error).to be_a(StandardError)
        expect(parser).to eq "Burlington 850"
        expect(filename).to eq "file.edi"
      end
      expect_any_instance_of(StandardError).to receive(:log_me).with ["File: file.edi"]

      subject.parse standard_edi, key: "file.edi"
    end

    it "doesn't update orders with revisions numbers lower than current one" do
      existing_order.update_custom_value! cdefs[:ord_revision], 20

      subject.parse standard_edi, bucket: "bucket", key: "file.edi"

      existing_order.reload
      expect(existing_order.order_lines.length).to eq 0
    end
  end

  describe "integration_folder" do
    it "uses the correct folder" do
      expect(described_class.integration_folder).to eq "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_burlington_850"
    end
  end
end
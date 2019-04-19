require 'spec_helper'

describe OpenChain::CustomHandler::Lt::Lt850Parser do
  let!(:data) { IO.read 'spec/fixtures/files/lt_850.edi' }
  let!(:importer) { Factory(:company, name: "LT", importer: true, system_code: "LOLLYT")}
  let(:cdefs) { described_class.new.cdefs }

  let!(:uae) { Factory(:country, iso_code: "AE") }
  let!(:us) { Factory(:country, iso_code: "US") }

  before(:all) {
    described_class.new.cdefs
  }

  after(:all) {
    CustomDefinition.destroy_all
  }

  describe "parse", :disable_delayed_jobs do
    
    subject { described_class }

    it "parses order" do
      subject.parse data, bucket: "bucket", key: "lt.edi"
      
      o = Order.where(order_number: "LOLLYT-417208").first
      expect(o.customer_order_number).to eq "417208"
      expect(o.importer).to eq importer
      expect(o.order_date).to eq Date.new(2018,7,31)
      expect(o.mode).to eq "AW"
      expect(o.terms_of_sale).to eq "01"
      expect(o.fob_point).to eq "NEW YORK"
      expect(o.currency).to eq "USD"
      expect(o.season).to eq "183FA 1"
      expect(o.ship_window_start).to eq Date.new(2018,8,13)
      expect(o.ship_window_end).to eq Date.new(2018,9,21)
      
      division = o.division
      expect(division.name).to eq "BRANDED ATHLETICS DIVISION"
      expect(division.company).to eq importer

      expect(o.custom_value(cdefs[:ord_type])).to eq "SA"
      expect(o.custom_value(cdefs[:ord_country_of_origin])).to eq "AE"

      vendor = o.vendor
      expect(vendor.name).to eq "FR APPAREL TRADING DMCC"
      expect(vendor.system_code).to eq "LOLLYT-Vendor-FRA001"
      addr = vendor.addresses.first
      expect(addr.line_1).to eq "UNIT 302-10, MSLI SERVICED OFF 1"
      expect(addr.line_2).to eq "JUMEIRAH LAKE TOWERS 1"
      expect(addr.city).to eq "DUBAI 1"
      expect(addr.postal_code).to eq "38306 1"
      expect(addr.country).to eq uae

      factory = o.factory
      expect(factory.name).to eq "FR APPAREL TRADING DMCC"
      expect(factory.system_code).to eq "LOLLYT-Factory-FRA001"
      expect(factory.mid).to eq "FRA001"
      addr = factory.addresses.first
      expect(addr.line_1).to eq "UNIT 302-10, MSLI SERVICED OFF 2"
      expect(addr.line_2).to eq "JUMEIRAH LAKE TOWERS 2"
      expect(addr.city).to eq "DUBAI 2"
      expect(addr.postal_code).to eq "38306 2"
      expect(addr.country).to eq uae

      expect(o.custom_value(cdefs[:ord_assigned_agent])).to eq "FR APPAREL TRADING"

      ship_to_addr = o.ship_to
      expect(o.ship_to.name).to eq "LT APPAREL GROUP"
      expect(ship_to_addr.line_1).to eq "301 HERROD BLVD"
      expect(ship_to_addr.city).to eq "DAYTON"
      expect(ship_to_addr.state).to eq "NJ"
      expect(ship_to_addr.postal_code).to eq "088101564"
      expect(o.ship_to.country).to eq us
      expect(o.order_lines.count).to eq 3
      ol1, ol2, ol3 = o.order_lines
      expect(ol1.line_number).to eq 28
      p1 = ol1.product
      expect(p1.unique_identifier).to eq "LOLLYT-ABKLSC"
      expect(p1.custom_value(cdefs[:prod_part_number])).to eq "ABKLSC"
      expect(p1.name).to eq "BOYS L/S KNIT TEE CLOSEOUTS"
      expect(ol1.quantity).to eq 672
      expect(ol1.unit_of_measure).to eq "EA 1"
      expect(ol1.sku).to eq "883180143626"
      expect(ol1.unit_msrp).to eq 1
      expect(ol1.price_per_unit).to eq 1.64
      expect(ol1.hts).to eq "6109100014"
      expect(ol1.custom_value(cdefs[:ord_line_color])).to eq "XX1"
      expect(ol1.custom_value(cdefs[:ord_line_color_description])).to eq "ASSORTED COLOR 1"
      expect(ol1.custom_value(cdefs[:ord_line_season])).to eq "183FA 2"
      expect(ol1.custom_value(cdefs[:ord_line_size])).to eq "PPK1"
      expect(ol1.custom_value(cdefs[:ord_line_size_description])).to eq "PPK2"

      expect(ol2.line_number).to eq 3001
      p2 = ol2.product
      expect(p2.unique_identifier).to eq "LOLLYT-ABSETS"
      expect(p2.custom_value(cdefs[:prod_part_number])).to eq "ABSETS"
      expect(p2.name).to eq "BOYS SETS CLOSEOUTS"
      expect(ol2.quantity).to eq 552
      expect(ol2.unit_of_measure).to eq "EA 2"
      expect(ol2.sku).to eq "192399830914"
      expect(ol2.unit_msrp).to eq 2
      expect(ol2.price_per_unit).to eq 1.94
      expect(ol2.hts).to eq "6103431540"
      expect(ol2.custom_value(cdefs[:ord_line_color])).to eq "XX2"
      expect(ol2.custom_value(cdefs[:ord_line_color_description])).to eq "ASSORTED COLOR 2"
      expect(ol2.custom_value(cdefs[:ord_line_season])).to eq "183FA 2" 
      expect(ol2.custom_value(cdefs[:ord_line_size])).to eq "PPK3"
      expect(ol2.custom_value(cdefs[:ord_line_size_description])).to eq "PPK4"

      expect(ol3.line_number).to eq 3002
      expect(ol3.product).to eq ol2.product
      expect(ol3.quantity).to eq 552
      expect(ol3.unit_of_measure).to eq "EA 2"
      expect(ol3.sku).to eq "192399830914"
      expect(ol3.unit_msrp).to eq 2
      expect(ol3.price_per_unit).to eq 1.94
      expect(ol3.hts).to eq "6109901009"
      expect(ol3.custom_value(cdefs[:ord_line_color])).to eq "XX2"
      expect(ol3.custom_value(cdefs[:ord_line_color_description])).to eq "ASSORTED COLOR 2"
      expect(ol3.custom_value(cdefs[:ord_line_season])).to eq "183FA 2" 
      expect(ol3.custom_value(cdefs[:ord_line_size])).to eq "PPK3"
      expect(ol3.custom_value(cdefs[:ord_line_size_description])).to eq "PPK4"
    end

    it "replaces existing lines" do
      old_ord = Factory(:order, importer: importer, order_number: "LOLLYT-417208")
      old_ord_ln = Factory(:order_line, order: old_ord)

      subject.parse data, bucket: "bucket", key: "lt.edi"
      expect{ old_ord_ln.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    it "assigns business-logic error to order without sending email" do
      expect_any_instance_of(subject).to receive(:handle_order_header).and_raise described_class::EdiBusinessLogicError.new("BUSINESS LOGIC ERROR!")
      subject.parse data, bucket: "bucket", key: "lt.edi"
      order = Order.where(order_number: "LOLLYT-417208").first
      expect(order.processing_errors).to eq "BUSINESS LOGIC ERROR!"
      expect(ActionMailer::Base.deliveries.pop).to be_nil
    end

    it "errors if REF segments don't include HTS qualifier" do
      data.gsub!(/REF\*HST.+$/, '')
      expect{ subject.parse data, bucket: "bucket", key: "lt.edi" }.to raise_error do |error|
        expect(error.class).to eq OpenChain::EdiParserSupport::EdiStructuralError
        expect(error.message).to eq "Order # 417208, UPC # 192399830914: Expecting REF with HST qualifier but none found"
      end
    end

    it "assigns blank HTS if none given" do
      data.gsub!("REF*HTS*6109.10.0014", "REF*HTS")
      subject.parse data, bucket: "bucket", key: "lt.edi"
      ol = Order.first.order_lines.first
      expect(ol.hts).to be_blank
    end
  end

  describe "update_standard_product" do
    let(:p) { Factory(:product, unique_identifier: "LOLLYT-ABKLSC", name: nil) }

    let(:line) do 
      t = REX12.each_transaction(StringIO.new(data)).first
      subject.extract_loop(t.segments, subject.line_level_segment_list).first
    end

    it "assigns product name and returns true" do
      expect(subject.update_standard_product p, "", "", line).to eq true
      expect(p.name).to eq "BOYS L/S KNIT TEE CLOSEOUTS"
    end

    it "returns false if product name unchanged" do
      p.update_attributes! name: "BOYS L/S KNIT TEE CLOSEOUTS"
      expect(subject.update_standard_product p, "", "", line).to eq false
      expect(p.name).to eq "BOYS L/S KNIT TEE CLOSEOUTS"
    end
  end

end


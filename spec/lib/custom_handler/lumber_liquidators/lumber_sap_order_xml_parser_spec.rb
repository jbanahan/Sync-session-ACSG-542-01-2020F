describe OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlParser do
  before :all do
    # This is here purely to speed up spec loading...so that the custom defs only have to get created once, since they can take a while to generate.
    described_class.new.send(:cdefs)
  end

  after :all do
    CustomDefinition.destroy_all
  end

  let :base_order do
    Factory(:order, order_number:'4700000325')
  end
  let :booked_order do
    subject.parse_dom(REXML::Document.new(IO.read('spec/fixtures/files/ll_sap_order.xml')), InboundFile.new)
    o = Order.first
    s = Factory(:shipment, vendor: o.vendor)
    o.order_lines.each do |ol|
      bl = s.booking_lines.build(quantity: ol.quantity, order_line: ol, line_number: ol.line_number)
      bl.save!
    end
    o
  end
  let :shipped_order do
    subject.parse_dom(REXML::Document.new(IO.read('spec/fixtures/files/ll_sap_order.xml')), InboundFile.new)
    o = Order.first
    s = Factory(:shipment, vendor: o.vendor)
    o.order_lines.each do |ol|
      bl = s.shipment_lines.build(quantity: ol.quantity, product: ol.product, line_number: ol.line_number)
      bl.linked_order_line_id = ol.id
      bl.save!
    end
    o
  end
  let! (:group) { Group.use_system_group("ORDER_REJECTED_EMAIL", name: "Order Rejected Email") }

  describe "parse_dom" do

    before :each do
      @usa = Factory(:country, iso_code:'US')
      @test_data = IO.read('spec/fixtures/files/ll_sap_order.xml')
      # Something is creating a master company prior to this setup...so just use it if it's there
      @importer = Company.where(master: true).first.presence || Factory(:master_company)
      @vendor = Factory(:company, vendor:true, system_code:'0000100131')
      @vendor_address = @vendor.addresses.create!(name:'VNAME', system_code:'123-CORP', line_1:'ln1', line_2:'l2', city:'New York', state:'NY', postal_code:'10001', country_id:@usa.id)
      @cdefs = subject.send(:cdefs)
      @product1= Factory(:product, name: 'Widgets', unique_identifier:'000000000010001547')
      @product_vendor_assignment = ProductVendorAssignment.create! product: @product1, vendor: @vendor
      @product_vendor_assignment.constant_texts.create! constant_text: "CARB", text_type: "CARB Statement", effective_date_start: Date.new(2000, 1, 1)
      @product_vendor_assignment.constant_texts.create! constant_text: "Patent", text_type: "Patent Statement", effective_date_start: Date.new(2000, 1, 1)
      cv = @product1.find_and_set_custom_value @cdefs[:prod_old_article], '123456'
      cv.save!
    end

    let!(:log) {
      log = InboundFile.new
      allow(subject).to receive(:inbound_file).and_return log
      log
    }

    it "should fail on bad root element" do
      @test_data.gsub!(/_-LUMBERL_-3PL_ORDERS05_EXT/, 'BADROOT')
      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to raise_error(/root element/)
      expect(log).to have_error_message "Incorrect root element BADROOT, expecting '_-LUMBERL_-3PL_ORDERS05_EXT, ORDERS05'."
    end

    it "should pass on legacy root element" do
      @test_data.gsub(/_-LUMBERL_-3PL_ORDERS05_EXT/, 'ORDERS05')
      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to change(Order, :count).from(0).to(1)
    end

    it "should create order" do
      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom, {key: "filename.xml"})}.to change(Order, :count).from(0).to(1)

      o = Order.first

      expect(o.importer).to eq @importer
      expect(o.vendor).to eq @vendor
      expect(o.order_number).to eq '4700000325'
      expect(o.customer_order_number).to eq o.order_number
      expect(o.order_date.strftime('%Y%m%d')).to eq '20140805'
      expect(o.get_custom_value(@cdefs[:ord_type]).value).to eq 'ZMSP'
      expect(o.get_custom_value(@cdefs[:ord_sap_extract]).value.to_i).to eq ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse('2014-12-17 14:33:21').to_i
      expect(o.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20160610'
      expect(o.ship_window_start.strftime('%Y%m%d')).to eq '20160601'
      expect(o.ship_window_end.strftime('%Y%m%d')).to eq '20160602'
      expect(o.get_custom_value(@cdefs[:ord_planned_expected_delivery_date]).value.strftime('%Y%m%d')).to eq '20160608'
      expect(o.get_custom_value(@cdefs[:ord_ship_confirmation_date]).value.strftime('%Y%m%d')).to eq '20160615'
      expect(o.get_custom_value(@cdefs[:ord_avail_to_prom_date]).value.strftime('%Y%m%d')).to eq '20141103'
      expect(o.get_custom_value(@cdefs[:ord_sap_vendor_handover_date]).value.strftime('%Y%m%d')).to eq '20160605'
      expect(o.currency).to eq 'USD'
      # No terms in XML should be "Due Immediately"
      expect(o.terms_of_payment).to eq 'Due Immediately'
      expect(o.terms_of_sale).to eq 'FOB'
      expect(o.fob_point).to eq('Free on Board')
      expect(o.get_custom_value(@cdefs[:ord_buyer_name]).value).to eq 'Purchasing Grp 100'
      expect(o.get_custom_value(@cdefs[:ord_buyer_phone]).value).to eq '804-463-2000'
      expect(o.get_custom_value(@cdefs[:ord_total_freight]).value).to eq 55.22
      # For each of the 3 lines, qty times price, then add total freight.
      expect(o.get_custom_value(@cdefs[:ord_grand_total]).value).to eq (((5602.8 * 1.85) + (8168.4 * 1.82) + (8168.4 * 1.82)).round(2) + 55.22)

      expect(o.order_from_address_id).to eq @vendor_address.id

      expect(o.get_custom_value(@cdefs[:ord_assigned_agent]).value).to be_blank

      expect(o.order_lines.size).to eq(3)

      # existing product
      ol = o.order_lines.find_by(line_number: 1)
      expect(ol.line_number).to eq 1
      expect(ol.product).to eq @product1
      expect(ol.quantity).to eq 5602.8
      expect(ol.price_per_unit).to eq 1.85
      expect(ol.unit_of_measure).to eq 'UOM'
      expect(ol.get_custom_value(@cdefs[:ordln_part_name]).value).to eq ol.product.name
      expect(ol.get_custom_value(@cdefs[:ordln_old_art_number]).value).to eq '123456'
      expect(ol.get_custom_value(@cdefs[:ordln_custom_article_description]).value).to eq "Custom Text:Sale # 124511692 Quote # ST 12311134-2\n11 Box Retread Hickory 36\" X 11.5\" X 5/8\" Pre-Finished Stained\n***CUSTOM***Casa De Colour Cherry Hickory"
      # Converted from LB to KG.
      expect(ol.get_custom_value(@cdefs[:ordln_gross_weight_kg]).value).to eq BigDecimal("4599.907")
      expect(ol.get_custom_value(@cdefs[:ordln_inland_freight_amount]).value).to eq 49.3
      expect(ol.get_custom_value(@cdefs[:ordln_inland_freight_vendor_number]).value).to eq '0000201814'
      # Vendor number (above) does not matches the @vendor's system code, resulting in this field getting a nil value.
      expect(ol.get_custom_value(@cdefs[:ordln_vendor_inland_freight_amount]).value).to be_nil
      expect(ol.get_custom_value(@cdefs[:ordln_deleted_flag]).value).to eq false
      expect(ol.custom_value(@cdefs[:ordln_carb_statement])).to eq "CARB"
      expect(ol.custom_value(@cdefs[:ordln_patent_statement])).to eq "Patent"

      ship_to = ol.ship_to
      expect(ship_to.name).to eq "LOS ANGELES CA 9444"
      expect(ship_to.line_1).to eq '6548 Telegraph Road'
      expect(ship_to.line_2).to be_blank
      expect(ship_to.city).to eq 'City of Commerce'
      expect(ship_to.state).to eq 'CA'
      expect(ship_to.postal_code).to eq '90040'
      expect(ship_to.country).to eq @usa
      expect(ship_to.system_code).to eq '9444'

      # new product
      ol2 = o.order_lines.find_by(line_number: 2)
      new_prod = ol2.product
      expect(new_prod.unique_identifier).to eq '000000000010003151'
      expect(new_prod.name).to eq 'MS STN Qing Drag Bam 9/16x3-3/4" Str'
      expect(new_prod.vendors.to_a).to eq [@vendor]
      expect(ol2.quantity).to eq 8168.4
      expect(ol2.price_per_unit).to eq 1.82
      expect(ol2.get_custom_value(@cdefs[:ordln_custom_article_description]).value).to eq "Custom Text Goes Here"
      # UOM is KG, so not converted.
      expect(ol2.get_custom_value(@cdefs[:ordln_gross_weight_kg]).value).to eq BigDecimal("25567.092")
      expect(ol2.get_custom_value(@cdefs[:ordln_inland_freight_amount]).value).to eq 55.22
      expect(ol2.get_custom_value(@cdefs[:ordln_inland_freight_vendor_number]).value).to eq '0000100131'
      # Vendor number (above) matches the @vendor's system code, resulting in this field getting the same value as the
      # inland freight amount (above).
      expect(ol2.get_custom_value(@cdefs[:ordln_vendor_inland_freight_amount]).value).to eq 55.22

      ol3 = o.order_lines.find_by(line_number: 3)
      expect(ol3.quantity).to eq 8168.4
      expect(ol3.price_per_unit).to eq 1.82

      expect(o.entity_snapshots.length).to eq 1
      snap = o.entity_snapshots.first
      expect(snap.context).to eq "filename.xml"

      folders = o.folders.order(:name).map { |f| {f_name: f.name, g_name: f.groups.first.name, g_system_code: f.groups.first.system_code } }
      expect(folders).to eq [{f_name:'Lacey Docs', g_name: 'RO/Product Compliance', g_system_code: 'ROPRODCOMP'},
                             {f_name: 'Quality', g_name: 'Quality', g_system_code: 'QUALITY'}]

      expect(log.company).to eq @importer
      expect(log).to have_identifier :po_number, "4700000325", Order, o.id
    end

    context "updates to booked" do
      let!(:master_setup) {
        ms = stub_master_setup
        allow(ms).to receive(:production?).and_return true
        ms
      }
      let :prep_mailer do
        m = double('mail')
        expect(m).to receive(:deliver_now)
        expect(OpenMailer).to receive(:send_simple_html).with(
          array_including(['ll-support@vandegriftinc.com', 'POResearch@lumberliquidators.com', group]),
          "Order 4700000325 XML rejected.",
          /Order 4700000325 was rejected/,
          [instance_of(Tempfile)]
        ).and_return(m)
      end
      let :do_parse do
        dom = REXML::Document.new(@test_data)
        subject.parse_dom(dom)
      end
      it "should allow updates to header" do
        booked_order.update_attributes(order_date: Time.now)
        do_parse
        expect(Order.first.order_date.strftime('%Y%m%d')).to eq '20140805'
        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
      it "should allow update to quantity" do
        # Prevents totals validation from failing.
        @test_data.gsub!('SUMME>40098.16</SUMME', 'SUMME>29736.31</SUMME')

        booked_order
        @test_data.gsub!('MENGE>5602.800</MENGE', 'MENGE>1.800</MENGE')
        do_parse
        expect(Order.first.order_lines.first.quantity).to eq 1.8
        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
      it "should not allow update to product" do
        prep_mailer
        booked_order
        @test_data.gsub!('IDTNR>000000000010001547</IDTNR', 'IDTNR>000000000010001541</IDTNR')
        do_parse
        expect(Order.first.order_lines.first.product.unique_identifier).to eq '000000000010001547'
      end
      it "should allow update to price" do
        # Prevents totals validation from failing.
        @test_data.gsub!('SUMME>40098.16</SUMME', 'SUMME>37296.76</SUMME')

        booked_order
        @test_data.gsub!('VPREI>1.85</VPREI', 'VPREI>1.35</VPREI')
        do_parse
        expect(Order.first.order_lines.first.price_per_unit).to eq 1.35
        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
      it "should soft delete a line not mentioned in the XML" do
        # Prevents totals validation from failing.
        @test_data.gsub!('SUMME>40098.16</SUMME', 'SUMME>29732.98</SUMME')

        booked_order
        new_dom = REXML::Document.new(@test_data)
        new_dom.root.elements.delete('IDOC/E1EDP01[1]')
        subject.parse_dom(new_dom)

        ord_lines = Order.first.order_lines
        expect(ord_lines.count).to eq 3
        # Line is not removed, but it is "soft deleted": flag set, quantity zeroed.
        expect(ord_lines.first.get_custom_value(@cdefs[:ordln_deleted_flag]).value).to eq true
        expect(ord_lines.first.quantity).to eq 0

        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
      it "should allow adding another line" do
        booked_order
        new_dom = REXML::Document.new(@test_data)
        lineEl = new_dom.root.elements['IDOC/E1EDP01[1]']
        lineEl.elements['POSEX'].text = '00009'
        new_dom.root.elements['IDOC'] << lineEl
        subject.parse_dom(new_dom)
        expect(Order.first.order_lines.count).to eq 4
        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
    end

    context "updates to shipped" do
      let!(:master_setup) {
        ms = stub_master_setup
        allow(ms).to receive(:production?).and_return true
        ms
      }
      let :prep_mailer do
        m = double('mail')
        expect(m).to receive(:deliver_now)
        expect(OpenMailer).to receive(:send_simple_html).with(
          array_including(['ll-support@vandegriftinc.com', 'POResearch@lumberliquidators.com', group]),
          "Order 4700000325 XML rejected.",
          /Order 4700000325 was rejected/,
          [instance_of(Tempfile)]
        ).and_return(m)
      end
      let :do_parse do
        dom = REXML::Document.new(@test_data)
        subject.parse_dom(dom)
      end
      it "should allow updates to header" do
        shipped_order.update_attributes(order_date: Time.now)
        do_parse
        expect(Order.first.order_date.strftime('%Y%m%d')).to eq '20140805'
        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
      it "should allow update to quantity" do
        # Prevents totals validation from failing.
        @test_data.gsub!('SUMME>40098.16</SUMME', 'SUMME>29736.31</SUMME')

        shipped_order
        @test_data.gsub!('MENGE>5602.800</MENGE', 'MENGE>1.800</MENGE')
        do_parse
        expect(Order.first.order_lines.first.quantity).to eq 1.8
        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
      it "should not allow update to product" do
        prep_mailer
        shipped_order
        @test_data.gsub!('IDTNR>000000000010001547</IDTNR', 'IDTNR>000000000010001541</IDTNR')
        do_parse
        expect(Order.first.order_lines.first.product.unique_identifier).to eq '000000000010001547'
      end
      it "should allow update to price" do
        # Prevents totals validation from failing.
        @test_data.gsub!('SUMME>40098.16</SUMME', 'SUMME>37296.76</SUMME')

        shipped_order
        @test_data.gsub!('VPREI>1.85</VPREI', 'VPREI>1.35</VPREI')
        do_parse
        expect(Order.first.order_lines.first.price_per_unit).to eq 1.35
        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
      it "should soft delete a line not mentioned in the XML" do
        # Prevents totals validation from failing.
        @test_data.gsub!('SUMME>40098.16</SUMME', 'SUMME>29732.98</SUMME')

        shipped_order
        new_dom = REXML::Document.new(@test_data)
        new_dom.root.elements.delete('IDOC/E1EDP01[1]')
        subject.parse_dom(new_dom)

        ord_lines = Order.first.order_lines
        expect(ord_lines.count).to eq 3
        # Line is not removed, but it is "soft deleted": flag set, quantity zeroed.
        expect(ord_lines.first.get_custom_value(@cdefs[:ordln_deleted_flag]).value).to eq true
        expect(ord_lines.first.quantity).to eq 0

        expect(ActionMailer::Base.deliveries.length).to eq 0
      end
      it "should allow adding another line" do
        shipped_order
        new_dom = REXML::Document.new(@test_data)
        lineEl = new_dom.root.elements['IDOC/E1EDP01[1]']
        lineEl.elements['POSEX'].text = '00009'
        new_dom.root.elements['IDOC'] << lineEl
        subject.parse_dom(new_dom)
        expect(Order.first.order_lines.count).to eq 4
      end
    end

    it "should not change order line part name if value is present" do
      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to change(Order, :count).from(0).to(1)

      o = Order.first
      ol = o.order_lines.find_by(line_number: 1)
      expect(ol.get_custom_value(@cdefs[:ordln_part_name]).value).to eq @product1.name

      old_product_name = @product1.name
      @product1.name = "This has changed"
      @product1.save!

      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to_not change(Order, :count)

      o = Order.first
      ol = o.order_lines.find_by(line_number: 1)
      expect(ol.get_custom_value(@cdefs[:ordln_part_name]).value).to eq old_product_name
    end

    it "should not change order line old article number if value is present" do
      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to change(Order, :count).from(0).to(1)

      o = Order.first
      ol = o.order_lines.find_by(line_number: 1)
      expect(ol.get_custom_value(@cdefs[:ordln_old_art_number]).value).to eq '123456'

      cv = @product1.find_and_set_custom_value @cdefs[:prod_old_article], '654321'
      cv.save!

      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to_not change(Order, :count)

      o = Order.first
      ol = o.order_lines.find_by(line_number: 1)
      expect(ol.get_custom_value(@cdefs[:ordln_old_art_number]).value).to eq '123456'
    end

    it "should update order" do
      base_order # makes order in database

      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to_not change(Order, :count)

      o = Order.first
      expect(o.order_lines.size).to eq(3)
    end
    it "should ignore blank inco terms" do
      base_order.update_attributes(terms_of_sale:'DDP')
      @test_data.gsub!('LKOND>FOB', 'LKOND>')
      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to_not change(Order, :count)
      base_order.reload
      expect(base_order.terms_of_sale).to eq 'DDP'
    end
    context 'assigned agent' do
      let :gelowell do
        gelowell = Factory(:company, system_code:'GELOWELL')
        gelowell.linked_companies << @vendor
        gelowell
      end
      let :ro do
        ro = Factory(:company, system_code:'RO')
        ro.linked_companies << @vendor
        ro
      end
      it "should set assigned agent to GELOWELL" do
        gelowell
        subject.parse_dom(REXML::Document.new(@test_data))

        expect(Order.first.get_custom_value(@cdefs[:ord_assigned_agent]).value).to eq 'GELOWELL'

      end
      it "should set assigned agent to RO" do
        ro
        subject.parse_dom(REXML::Document.new(@test_data))

        expect(Order.first.get_custom_value(@cdefs[:ord_assigned_agent]).value).to eq 'RO'

      end
      it "should set assigned agent to GELOWELL/RO" do
        gelowell
        ro
        subject.parse_dom(REXML::Document.new(@test_data))

        expect(Order.first.get_custom_value(@cdefs[:ord_assigned_agent]).value).to eq 'GELOWELL/RO'

      end
    end
    it "should not update order if previous extract time is newer than this doc" do
      existing_order = Factory(:order, order_number:'4700000325')
      # update sap extract to future date so this doc shouldn't update it
      existing_order.update_custom_value!(@cdefs[:ord_sap_extract], 1.day.from_now)

      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to_not change(Order, :count)

      o = Order.first
      # didn't write the order
      expect(o.order_lines.size).to eq(0)
    end

    context 'first expected delivery date' do
      it "should use CURR_ARRVD for first_expected_delivery_date if it is populated" do
        subject.parse_dom(REXML::Document.new(@test_data))
        expect(Order.first.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20160610'
      end
      it "should use EDATU for first_expected_delivery_date if CURR_ARRVD is blank and VN_HNDDTE is populated with a valid date" do
        @test_data.gsub!(/<CURR_ARRVD.*CURR_ARRVD>/, '<CURR_ARRVD></CURR_ARRVD>')
        subject.parse_dom(REXML::Document.new(@test_data))
        expect(Order.first.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20141103'
      end
      it "should use VN_EXPEC_DLVD for first_expected_delivery_date if CURR_ARRVD is blank and VN_HNDDTE is not populated with a valid date" do
        @test_data.gsub!(/<CURR_ARRVD.*CURR_ARRVD>/, '<CURR_ARRVD></CURR_ARRVD>')
        @test_data.gsub!(/<VN_HNDDTE.*VN_HNDDTE>/, '<VN_HNDDTE></VN_HNDDTE>')
        subject.parse_dom(REXML::Document.new(@test_data))
        expect(Order.first.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20160608'
      end
    end

    context 'unit of measure' do
      it 'should convert FTK to FT2' do
        @test_data.gsub!('UOM', 'FTK')
        subject.parse_dom(REXML::Document.new(@test_data))
        expect(OrderLine.pluck(:unit_of_measure).first).to eq 'FT2'
      end
      it 'should convert FOT to FT' do
        @test_data.gsub!('UOM', 'FOT')
        subject.parse_dom(REXML::Document.new(@test_data))
        expect(OrderLine.pluck(:unit_of_measure).first).to eq 'FT'
      end
    end
    it "should not blow up on dates that are all zeros" do
      @test_data.gsub!(/<CURR_ARRVD.*CURR_ARRVD>/, '<CURR_ARRVD>00000000</CURR_ARRVD>')
      dom = REXML::Document.new(@test_data)
      subject.parse_dom(dom)

      o = Order.first
      expect(o.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20141103'
    end

    it "should fall back to old matrix if _-LUMBERL_-PO_SHIP_WINDOW segment doesn't exist" do
      dom = REXML::Document.new(@test_data)
      dom.root.elements.delete_all(".//_-LUMBERL_-PO_SHIP_WINDOW")
      subject.parse_dom(dom)

      o = Order.first
      expect(o.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20141103'
      expect(o.ship_window_start.strftime('%Y%m%d')).to eq '20140909'
      expect(o.ship_window_end.strftime('%Y%m%d')).to eq '20140916'
    end

    it "should fall back to old matrix if all new dates are 00000000" do
      ['CURR_ARRVD', 'VN_HNDDTE', 'VN_EXPEC_DLVD', 'VN_SHIPBEGIN', 'VN_SHIPEND', 'ACT_SHIP_DATE'].each do |d_tag|
        @test_data.gsub!(/<#{d_tag}.*#{d_tag}>/, "<#{d_tag}>00000000</#{d_tag}>")
      end

      dom = REXML::Document.new(@test_data)
      subject.parse_dom(dom)

      o = Order.first
      expect(o.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20141103'

    end

    it "should fall back to old matrix if no VN_EXPEC_DLVD" do
      # this happens when LL has not replanned an old order before July 2016 that has already shipped
      ['VN_EXPEC_DLVD', 'VN_SHIPBEGIN', 'VN_SHIPEND'].each do |d_tag|
        @test_data.gsub!(/<#{d_tag}.*#{d_tag}>/, "<#{d_tag}>00000000</#{d_tag}>")
      end
      @test_data.gsub!(/<CURR_ARRVD.*CURR_ARRVD>/, "<CURR_ARRVD>20141103</CURR_ARRVD>")
      dom = REXML::Document.new(@test_data)
      subject.parse_dom(dom)
      o = Order.first
      expect(o.first_expected_delivery_date.strftime('%Y%m%d')).to eq '20141103'
      expect(o.ship_window_start.strftime('%Y%m%d')).to eq '20140909'
      expect(o.ship_window_end.strftime('%Y%m%d')).to eq '20140916'
    end

    it "should use ship to address from header if nothing at line" do
      dom = REXML::Document.new(@test_data)
      first_address = REXML::XPath.first(dom.root, "IDOC/E1EDP01/E1EDPA1[PARVW = 'WE']")
      dom.root.elements.delete_all("IDOC/E1EDP01/E1EDPA1[PARVW = 'WE']")
      REXML::XPath.first(dom.root, 'IDOC').add_element first_address
      subject.parse_dom(dom)

      o = Order.first

      expect(ModelField.find_by_uid(:ord_ship_to_count).process_export(o, nil, true)).to eq 1
      st = o.order_lines.first.ship_to

      expect(st.name).to eq 'LOS ANGELES CA 9444'
    end

    it "should re-use existing address" do
      oa = @importer.addresses.new
      oa.name = "LOS ANGELES CA 9444"
      oa.line_1 = '6548 Telegraph Road'
      oa.city = 'City of Commerce'
      oa.state = 'CA'
      oa.postal_code = '90040'
      oa.country = @usa
      oa.system_code = '9444'
      oa.save!

      dom = REXML::Document.new(@test_data)
      subject.parse_dom(dom)

      expect(Order.first.order_lines.first.ship_to_id).to eq oa.id
    end

    it "should not set order from address if no -CORP address" do
      @vendor_address.update_attributes(system_code:"OTHER")
      subject.parse_dom(REXML::Document.new(@test_data))

      expect(Order.first.order_from_address).to be_nil
    end

    it "should create vendor if not found" do
      # clear the vendor
      expect {@vendor.destroy}.to change(Company, :count).by(-1)

      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to change(Company, :count).by(1)

      vendor = Company.find_by(system_code: '0000100131', vendor: true)
      expect(vendor).to_not be_nil

      expect(@importer.linked_companies).to include(vendor)

      expect(Order.first.vendor).to eq vendor
    end
    it "should fail if total cost != line costs" do
      td = @test_data.gsub(/<SUMME>40098.16<\/SUMME>/, "<SUMME>40098.15</SUMME>")
      dom = REXML::Document.new(td)

      expect {subject.parse_dom(dom)}.to raise_error("Unexpected order total. Got 40098.16, expected 40098.15")
      expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "Unexpected order total. Got 40098.16, expected 40098.15"
    end

    it "should delete order line" do
      dom = REXML::Document.new(@test_data)
      expect {subject.parse_dom(dom)}.to change(OrderLine, :count).from(0).to(3)
      td = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>NT00</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>25231.67</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      dom = REXML::Document.new(td)
      expect {subject.parse_dom(dom)}.to change(OrderLine, :count).from(3).to(2)

      expect(Order.first.order_lines.collect {|ol| ol.line_number}).to eq [1, 3]
    end

    it "sets article description to nil if no description is sent" do
      dom = REXML::Document.new(@test_data)
      subject.parse_dom(dom)
      dom.root.elements.delete_all "/_-LUMBERL_-3PL_ORDERS05_EXT/IDOC/E1EDP01/E1EDPT1"
      subject.parse_dom(dom)

      o = Order.first
      expect(o.order_lines.first.custom_value(@cdefs[:ordln_custom_article_description])).to be_nil
    end

    it "sets article description to blank if a blank string is already present" do
      dom = REXML::Document.new(@test_data)
      subject.parse_dom(dom)
      o = Order.first
      o.order_lines.first.update_custom_value! @cdefs[:ordln_custom_article_description], ""

      dom.root.elements.delete_all "/_-LUMBERL_-3PL_ORDERS05_EXT/IDOC/E1EDP01/E1EDPT1"
      subject.parse_dom(dom)

      o.reload
      expect(o.order_lines.first.custom_value(@cdefs[:ordln_custom_article_description])).to eq ""
    end

    it "handles complex payment terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>NT00</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>10</TAGE><PRZNT>10.000</PRZNT></E1EDK18><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>20</TAGE><PRZNT>5.500</PRZNT></E1EDK18><E1EDK18 SEGMENT="1"><QUALF>002</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "10% 10 Days, 5.5% 20 Days, Net 30"
    end

    it "handles simplified payment terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>NT00</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "Net 30"
    end

    it "handles special case LC60 terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>LC60</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "Letter of Credit 60 Days"
    end

    it "handles special case TT00 terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>TT00</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "T/T At Sight"
    end

    it "handles special case TT terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>TT21</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "T/T Net 21"
    end

    it "handles special case TT30 terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>TT30</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "T/T Net 30"
    end

    it "handles special case D001 terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>D001</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "T/T .5% 15 Days, Net 15"
    end

    it "handles special case D002 terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>D002</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "T/T 1% 15 Days, Net 15"
    end

    it "handles special case D007 terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>D007</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "T/T 1% 10 Days, Net 30"
    end

    it "handles special case D008 terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>D008</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "T/T 1% 30 Days, Net 31"
    end

    it "handles special case T120 terms" do
      xml = '<?xml version="1.0" encoding="UTF-8" ?><ORDERS05><IDOC BEGIN="1"><EDI_DC40 SEGMENT="1"><TABNAM>EDI_DC40</TABNAM><MANDT>100</MANDT><DOCNUM>0000000064132944</DOCNUM><DOCREL>701</DOCREL><STATUS>30</STATUS><DIRECT>1</DIRECT><OUTMOD>4</OUTMOD><IDOCTYP>ORDERS05</IDOCTYP><MESTYP>/LUMBERL/VFI_ORDERS</MESTYP><SNDPOR>SAPEQ2</SNDPOR><SNDPRT>LS</SNDPRT><SNDPRN>EQ2CLNT100</SNDPRN><RCVPOR>PIQCLNT001</RCVPOR><RCVPRT>LS</RCVPRT><RCVPFC>LS</RCVPFC><RCVPRN>VFIDEV</RCVPRN><CREDAT>20141217</CREDAT><CRETIM>143321</CRETIM><SERIAL>20141217143320</SERIAL></EDI_DC40><E1EDK01 SEGMENT="1"><CURCY>USD</CURCY><HWAER>USD</HWAER><WKURS>1.00000</WKURS><ZTERM>T120</ZTERM><BSART>ZMSP</BSART><BELNR>4700000325</BELNR><RECIPNT_NO>0000100131</RECIPNT_NO></E1EDK01><E1EDK14 SEGMENT="1"><QUALF>014</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>009</QUALF><ORGID>100</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>013</QUALF><ORGID>ZMSP</ORGID></E1EDK14><E1EDK14 SEGMENT="1"><QUALF>011</QUALF><ORGID>1000</ORGID></E1EDK14><E1EDK17 SEGMENT="1"><QUALF>001</QUALF><LKOND>FOB</LKOND><LKTEXT>Free on Board</LKTEXT></E1EDK17><E1EDK18 SEGMENT="1"><QUALF>001</QUALF><TAGE>30</TAGE></E1EDK18><E1EDK03 SEGMENT="1"><IDDAT>012</IDDAT><DATUM>20140805</DATUM></E1EDK03><E1EDK03 SEGMENT="1"><IDDAT>011</IDDAT><DATUM>20141217</DATUM></E1EDK03><E1EDKA1 SEGMENT="1"><PARVW>AG</PARVW><PARTN>1000</PARTN><TELF1>804-463-2000</TELF1><BNAME>Purchasing Grp 100</BNAME><PAORG>1000</PAORG><ORGTX>Purch. Org. 1000</ORGTX><PAGRU>100</PAGRU></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LF</PARVW><PARTN>0000100131</PARTN><SPRAS>E</SPRAS><SPRAS_ISO>EN</SPRAS_ISO></E1EDKA1><E1EDKA1 SEGMENT="1"><PARVW>LS</PARVW><PARTN>0000100131</PARTN></E1EDKA1><E1EDK02 SEGMENT="1"><QUALF>001</QUALF><BELNR>4700000325</BELNR><DATUM>20140805</DATUM><UZEIT>143320</UZEIT></E1EDK02><E1EDP01 SEGMENT="1"><POSEX>00001</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>5602.800</MENGE><MENEE>UOM</MENEE><BMNG2>5602.800</BMNG2><PMENE>UOM</PMENE><VPREI>1.85</VPREI><PEINH>1</PEINH><NETWR>10365.18</NETWR><NTGEW>10141.068</NTGEW><GEWEI>LBR</GEWEI><MATKL>111408</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>10141.068</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>5602.800</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>LOS ANGELES CA 9444</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>6548 Telegraph Road</STRAS><ORT01>City of Commerce</ORT01><PSTLZ>90040</PSTLZ><LAND1>US</LAND1><TELF1>3237210800</TELF1><TELFX>3237218079</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010001547</IDTNR><KTEXT>SCH ENG Bamboo QC 9/16x5" Strand Nat</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00002</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20141103</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDP01 SEGMENT="1"><POSEX>00003</POSEX><ACTION>001</ACTION><PSTYP>0</PSTYP><MENGE>8168.400</MENGE><MENEE>UOM</MENEE><BMNG2>8168.400</BMNG2><PMENE>UOM</PMENE><VPREI>1.82</VPREI><PEINH>1</PEINH><NETWR>14866.49</NETWR><NTGEW>25567.092</NTGEW><GEWEI>LBR</GEWEI><MATKL>111301</MATKL><BPUMN>1</BPUMN><BPUMZ>1</BPUMZ><BRGEW>25567.092</BRGEW><WERKS>9444</WERKS><LGORT>1000</LGORT><E1EDP20 SEGMENT="1"><WMENG>8168.400</WMENG><AMENG>0.000</AMENG><EDATU>20150316</EDATU></E1EDP20><E1EDPA1 SEGMENT="1"><PARVW>WE</PARVW><LIFNR>9444</LIFNR><NAME1>WEST LA CA 1113</NAME1><NAME2>Angel Aguilar</NAME2><STRAS>11612 W. Olympic Blvd.</STRAS><ORT01>Los Angeles</ORT01><PSTLZ>90064</PSTLZ><LAND1>US</LAND1><TELF1>2137853456</TELF1><TELFX>2137853458</TELFX><SPRAS>E</SPRAS><ORT02>LOS ANGELES</ORT02><REGIO>CA</REGIO></E1EDPA1><E1EDP19 SEGMENT="1"><QUALF>001</QUALF><IDTNR>000000000010003151</IDTNR><KTEXT>MS STN Qing Drag Bam 9/16x3-3/4" Str</KTEXT></E1EDP19></E1EDP01><E1EDS01 SEGMENT="1"><SUMID>002</SUMID><SUMME>40098.16</SUMME><SUNIT>USD</SUNIT></E1EDS01></IDOC></ORDERS05>'
      subject.parse_dom(REXML::Document.new(xml))

      o = Order.where(order_number: "4700000325").first
      expect(o.terms_of_payment).to eq "T/T 120 Days"
    end
  end

  describe "setup_folders" do
    let!(:ord) { Factory(:order) }
    let!(:user) { User.integration }

    it "creates folders for order" do
      subject.setup_folders ord
      folders = ord.folders.order(:name).map { |f| {f_name: f.name, f_base_object: f.base_object, f_created_by_id: f.created_by_id, g_name: f.groups.first.name, g_system_code: f.groups.first.system_code } }
      expect(folders).to eq [{f_name:'Lacey Docs', f_base_object: ord, f_created_by_id: user.id, g_name: 'RO/Product Compliance', g_system_code: 'ROPRODCOMP'},
                             {f_name: 'Quality', f_base_object: ord, f_created_by_id: user.id, g_name: 'Quality', g_system_code: 'QUALITY'}]
    end

    it "skips creating folders that already exist" do
      Factory(:folder, base_object: ord, created_by: user, name: 'Quality')
      subject.setup_folders ord
      expect(ord.folders.where(name: "Quality").count).to eq 1
    end

  end
end

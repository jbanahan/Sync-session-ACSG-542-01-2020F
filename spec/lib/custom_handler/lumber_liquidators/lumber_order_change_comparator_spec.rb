require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator do
  let :order_data_klass do
    described_class::OrderData
  end
  describe '#compare' do
    it 'should do nothing if not an Order type' do
      expect(described_class).not_to receive(:run_changes)
      described_class.compare 'Product', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
    it 'should build OrderData objects and execute_business_logic' do
      old_data = double('old_order_data')
      new_data = double('new_order_data')
      expect(described_class).to receive(:build_order_data).with('ob','op','ov').and_return old_data
      expect(described_class).to receive(:build_order_data).with('nb','np','nv').and_return new_data
      expect(described_class).to receive(:execute_business_logic).with(1,old_data,new_data)
      described_class.compare 'Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
  end

  describe 'build_order_data' do
    it 'should return nil if bucket is nil' do
      expect(described_class.build_order_data(nil, nil, nil)).to be_nil
    end
    it 'should return from JSON hash if bucket is not nil' do
      h = double('hash')
      od = double('OrderData')
      expect(described_class).to receive(:get_json_hash).with('a','b','c').and_return h
      expect(order_data_klass).to receive(:build_from_hash).with(h).and_return od
      expect(described_class.build_order_data('a','b','c')).to eq od
    end
  end

  describe '#execute_business_logic' do
    before :each do
      @order_id = 1
      @o = double('order')
      allow(@o).to receive(:reload)
      @old_data = double('od')
      @new_data = double('nd')
      allow(Order).to receive(:find_by_id).and_return @o

      # stub all business logic methods, then in each test we use should_receive for the one we're testing
      allow(described_class).to receive(:set_defaults).and_return false
      allow(described_class).to receive(:clear_planned_handover_date).and_return false
      allow(described_class).to receive(:set_forecasted_handover_date).and_return false
      allow(described_class).to receive(:update_autoflow_approvals).and_return false
      allow(described_class).to receive(:reset_vendor_approvals).and_return false
      allow(described_class).to receive(:reset_product_compliance_approvals).and_return false
      allow(described_class).to receive(:set_price_revised_dates).and_return false
      allow(described_class).to receive(:generate_ll_xml)
      allow(described_class).to receive(:reset_po_cancellation).and_return false
      allow(described_class).to receive(:create_pdf).and_return false
    end
    it 'should return if order does not exist' do
      allow(Order).to receive(:find_by_id).and_return nil
      expect(described_class).not_to receive(:set_defaults)
      expect(described_class.execute_business_logic(1,@old_data,@new_data)).to be_falsey
    end
    it 'should set defaults' do
      expect(described_class).to receive(:set_defaults).with(@o,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should clear planned handover date' do
      expect(described_class).to receive(:clear_planned_handover_date).with(@o,@old_data,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should set forecasted handover date' do
      expect(described_class).to receive(:set_forecasted_handover_date).with(@o)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should reset vendor approvals' do
      expect(described_class).to receive(:reset_vendor_approvals).with(@o,@old_data,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should reset PC / Exec PC approvals' do
      expect(described_class).to receive(:reset_product_compliance_approvals).with(@o,@old_data,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should set price revised dates' do
      expect(described_class).to receive(:set_price_revised_dates).with(@o,@old_data,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should autoflow' do
      expect(described_class).to receive(:update_autoflow_approvals).with(@o)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should reset PO cancellation' do
      expect(described_class).to receive(:reset_po_cancellation).with(@o)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should generate new PDF' do
      allow(described_class).to receive(:set_defaults).and_return false
      expect(described_class).to receive(:create_pdf).with(@o,@old_data,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should not generate new PDF if default values were updated' do
      allow(described_class).to receive(:set_defaults).and_return true
      expect(described_class).not_to receive(:create_pdf)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should generate xml' do
      expect(described_class).to receive(:generate_ll_xml).with(@o,@old_data,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
  end

  describe '#set_price_revised_dates' do
    before :each do
      @cdefs = described_class.prep_custom_definitions([:ord_sap_extract,:ord_price_revised_date,:ordln_price_revised_date])
      @o = Factory(:order_line,line_number:1).order
      @extract_timestamp = Time.now.utc
    end

    it "should do nothing if price didn't change" do
      expect(@o).to_not receive(:create_snapshot)
      od = double('old_data')
      nd = double('new_data')
      allow(nd).to receive(:sap_extract_date).and_return @extract_timestamp
      expect(order_data_klass).to receive(:lines_with_changed_price).with(od,nd).and_return []
      expect(described_class.set_price_revised_dates(@o,od,nd)).to be_falsey
      o = Order.find @o.id
      expect(o.custom_value(@cdefs[:ord_price_revised_date])).to be_nil
      expect(o.order_lines.first.custom_value(@cdefs[:ordln_price_revised_date])).to be_nil
    end
    it "should update if price on existing line changed" do
      expect(@o).to receive(:create_snapshot)
      od = double('old_data')
      nd = double('new_data')
      expect(nd).to receive(:sap_extract_date).and_return @extract_timestamp
      expect(order_data_klass).to receive(:lines_with_changed_price).with(od,nd).and_return [1]
      expect(described_class.set_price_revised_dates(@o,od,nd)).to be_truthy
      o = Order.find @o.id
      expect(o.custom_value(@cdefs[:ord_price_revised_date]).to_i).to eq @extract_timestamp.to_i
      expect(o.order_lines.first.custom_value(@cdefs[:ordln_price_revised_date]).to_i).to eq @extract_timestamp.to_i
    end
  end

  describe '#clear_planned_handover_date' do
    before :each do
      @cdefs = described_class.prep_custom_definitions([:ord_planned_handover_date])
      @o = Factory(:order)
      @o.update_custom_value!(@cdefs[:ord_planned_handover_date],Date.new(2016,10,1))
    end
    def base_data dates=[Date.new(2016,8,15),Date.new(2016,9,1)]
      data = double(:data)
      allow(data).to receive(:ship_window_start).and_return dates[0]
      allow(data).to receive(:ship_window_end).and_return dates[1]
      data
    end
    it "should clear planned handover date if ship window start changes" do
      expect_any_instance_of(Order).to receive(:create_snapshot).with(instance_of(User),nil,"System Job: Order Change Comparator: Clear Planned Handover")
      old_data = base_data
      new_data = base_data([Date.new(2016,8,10),Date.new(2016,9,1)])
      expect(described_class.clear_planned_handover_date(@o,old_data,new_data)).to be_truthy
      @o.reload
      expect(@o.custom_value(@cdefs[:ord_planned_handover_date])).to be_blank
    end
    it "should clear planned handover date if ship window end changes" do
      expect_any_instance_of(Order).to receive(:create_snapshot).with(instance_of(User),nil,"System Job: Order Change Comparator: Clear Planned Handover")
      old_data = base_data
      new_data = base_data([Date.new(2016,8,15),Date.new(2016,9,10)])
      expect(described_class.clear_planned_handover_date(@o,old_data,new_data)).to be_truthy
      @o.reload
      expect(@o.custom_value(@cdefs[:ord_planned_handover_date])).to be_blank
    end
    it "should not clear if ship window stays the same" do
      expect_any_instance_of(Order).to_not receive(:create_snapshot)
      old_data = base_data
      new_data = base_data
      expect(described_class.clear_planned_handover_date(@o,old_data,new_data)).to be_falsey
      @o.reload
      expect(@o.custom_value(@cdefs[:ord_planned_handover_date])).to_not be_blank
    end
    it "should return immediately if planned_handover_date is empty" do
      expect_any_instance_of(Order).to_not receive(:create_snapshot)
      @o.update_custom_value!(@cdefs[:ord_planned_handover_date],nil)
      old_data = base_data
      new_data = base_data([Date.new(2016,8,15),Date.new(2016,9,10)])
      expect(described_class.clear_planned_handover_date(@o,old_data,new_data)).to be_falsey
      @o.reload
      expect(@o.custom_value(@cdefs[:ord_planned_handover_date])).to be_blank
    end
  end

  describe '#set_forecasted_handover_date' do
    # PER SOW 1100 (2016-11-04), Forecasted Handover Date is being relabelled as Forecasted Ship Window End, but we're leaving the variables in the code alone
    # all tests also confirm that forecasted ship window start is set to 7 days prior to forecasted handover date
    before :each do
      @cdefs = described_class.prep_custom_definitions([:ord_forecasted_handover_date,:ord_planned_handover_date,:ord_forecasted_ship_window_start])
      @o = Factory(:order,ship_window_end:Date.new(2016,5,10))
    end
    it "should set forecasted handover date to planned_handover_date if planned_handover_date is not blank" do
      expect_any_instance_of(Order).to receive(:create_snapshot).with(instance_of(User),nil,"System Job: Order Change Comparator: Forecasted Window Update")
      @o.update_custom_value!(@cdefs[:ord_planned_handover_date],Date.new(2016,5,15))
      expect(described_class.set_forecasted_handover_date(@o)).to eq true
      expect(@o.get_custom_value(@cdefs[:ord_forecasted_handover_date]).value).to eq Date.new(2016,5,15)
      expect(@o.get_custom_value(@cdefs[:ord_forecasted_ship_window_start]).value).to eq Date.new(2016,5,8)
    end
    it "should set forecasted handover date to ship_window_end if planned_handover_date is blank" do
      expect_any_instance_of(Order).to receive(:create_snapshot).with(instance_of(User),nil,"System Job: Order Change Comparator: Forecasted Window Update")
      expect(described_class.set_forecasted_handover_date(@o)).to eq true
      expect(@o.get_custom_value(@cdefs[:ord_forecasted_handover_date]).value).to eq Date.new(2016,5,10)
      expect(@o.get_custom_value(@cdefs[:ord_forecasted_ship_window_start]).value).to eq Date.new(2016,5,3)
    end
    it "should return false if did not change" do
      expect_any_instance_of(Order).to_not receive(:create_snapshot)
      @o.update_custom_value!(@cdefs[:ord_forecasted_handover_date],Date.new(2016,5,10))
      expect(described_class.set_forecasted_handover_date(@o)).to eq false
      @o.reload
      expect(@o.get_custom_value(@cdefs[:ord_forecasted_handover_date]).value).to eq Date.new(2016,5,10)
    end
  end

  describe '#generate ll xml' do
    it 'should send xml to ll if ord_planned_handover_date has changed' do
      o = double ('order')
      od = double('OrderData-Old')
      allow(od).to receive(:planned_handover_date).and_return Date.new(2016,5,1)
      nd = double('OrderData-New')
      allow(nd).to receive(:planned_handover_date).and_return Date.new(2016,5,2)
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator).to receive(:send_order).with(o)
      described_class.generate_ll_xml(o,od,nd)
    end

    it "sends xml if old data is blank and new data has planned handover date" do
      o = double ('order')
      nd = double('OrderData-New')
      allow(nd).to receive(:planned_handover_date).and_return Date.new(2016,5,2)
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator).to receive(:send_order).with(o)
      described_class.generate_ll_xml(o,nil,nd)
    end

    it "does not sends xml if old data is blank and new data does not have planned handover date" do
      o = double ('order')
      nd = double('OrderData-New')
      allow(nd).to receive(:planned_handover_date).and_return nil
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator).not_to receive(:send_order)
      described_class.generate_ll_xml(o,nil,nd)
    end
  end

  describe '#set_defaults' do
    before :each do
      @k = OpenChain::CustomHandler::LumberLiquidators::LumberOrderDefaultValueSetter
    end
    it 'should call if order_data#has_blank_defaults?' do
      o = double('order')
      d = double('OrderData')
      expect(d).to receive(:has_blank_defaults?).and_return true
      expect(@k).to receive(:set_defaults).with(o).and_return true
      expect(described_class.set_defaults(o,d)).to be_truthy
    end
    it 'should return false if has_blank_defaults? but nothing is changed' do
      o = double('order')
      d = double('OrderData')
      expect(d).to receive(:has_blank_defaults?).and_return true
      expect(@k).to receive(:set_defaults).with(o).and_return false
      expect(described_class.set_defaults(o,d)).to be_falsey
    end
    it 'should not call if !order_data#has_blank_defaults?' do
      o = double('order')
      d = double('OrderData')
      expect(d).to receive(:has_blank_defaults?).and_return false
      expect(@k).not_to receive(:set_defaults)
      expect(described_class.set_defaults(o,d)).to be_falsey
    end

  end

  describe 'reset_po_cancellation' do
    before :each do
      @cdef = described_class.prep_custom_definitions([:ord_cancel_date])[:ord_cancel_date]
      @ord = Factory(:order, closed_at: nil)
      @ord.update_custom_value! @cdef, nil
    end

    it "reopens and uncancels order if it has lines and a cancel date, returns 'true'" do
      Factory(:order_line, order: @ord)
      @ord.update_custom_value! @cdef, Date.today
      @ord.update_attributes(closed_at: DateTime.now)

      expect(described_class.reset_po_cancellation @ord).to eq true
      cancel_date = @ord.get_custom_value @cdef
      expect(cancel_date.value).to be_nil
      expect(@ord.closed_at).to be_nil
    end

    it "closes and cancels order if it is doesn't have lines or a cancel date, returns true" do
      expect(described_class.reset_po_cancellation @ord).to eq true
      cancel_date = @ord.get_custom_value @cdef
      expect(cancel_date.value).not_to be_nil
      expect(@ord.closed_at).not_to be_nil
    end

    it "makes no change if order has lines but no cancel date, returns 'false'" do
      closed = DateTime.now - 10
      @ord.update_attributes(closed_at: closed)
      Factory(:order_line, order: @ord)
      expect(described_class.reset_po_cancellation @ord).to eq false
      cancel_date = @ord.get_custom_value @cdef
      expect(cancel_date.value).to be_nil
      expect(@ord.closed_at).to eq closed
    end

    it "makes no change if order has a cancel date and no lines, returns 'false'" do
      closed = DateTime.now - 10
      @ord.update_attributes(closed_at: closed)
      @ord.update_custom_value! @cdef, Date.today
      expect(described_class.reset_po_cancellation @ord).to eq false
      cancel_date = @ord.get_custom_value @cdef
      expect(cancel_date.value).to eq Date.today
      expect(@ord.closed_at).to eq closed
    end
  end

  describe '#update_autoflow_approvals' do
    it 'should call AutoFlowApprover' do
      o = double('order')
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover).to receive(:process).with(o).and_return true
      expect(described_class.update_autoflow_approvals(o)).to be_truthy
    end
    it 'should return value of AutoFlowApprover' do
      o = double('order')
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover).to receive(:process).with(o).and_return false
      expect(described_class.update_autoflow_approvals(o)).to be_falsey
    end
  end

  describe '#reset_vendor_approvals' do
    before :each do
      @nd = double('newdata')
      @od = double('olddata')
      @o = double(:order)
      @u = double(:user)
      allow(User).to receive(:integration).and_return @u
    end
    it 'should reset if OrderData#vendor_approval_reset_fields_changed? and order is accepted' do
      expect(order_data_klass).to receive(:vendor_approval_reset_fields_changed?).with(@od,@nd).and_return true
      expect(@o).to receive(:approval_status).and_return 'Accepted'
      expect(@o).to receive(:unaccept!).with(@u)
      expect(described_class.reset_vendor_approvals(@o,@od,@nd)).to be_truthy
    end
    it 'should not reset if !OrderData#vendor_approval_reset_fields_changed?' do
      expect(order_data_klass).to receive(:vendor_approval_reset_fields_changed?).with(@od,@nd).and_return false
      expect(@o).not_to receive(:unaccept!)
      expect(described_class.reset_vendor_approvals(@o,@od,@nd)).to be_falsey
    end
    it 'should not reset if OrderData#vendor_approval_reset_fields_changed? && order not accepted' do
      expect(order_data_klass).to receive(:vendor_approval_reset_fields_changed?).with(@od,@nd).and_return true
      expect(@o).to receive(:approval_status).and_return ''
      expect(@o).not_to receive(:unaccept!)
      expect(described_class.reset_vendor_approvals(@o,@od,@nd)).to be_falsey
    end
  end

  describe '#reset_product_compliance_approvals' do
    before :each do
      @od = double(:old_data)
      @nd = double(:new_data)
      @ord = Factory(:order)
      @ol1 = Factory(:order_line,order:@ord,line_number:'1')
      @ol2 = Factory(:order_line,order:@ord,line_number:'2')
      @ord.reload
      @u = Factory(:user)
      @integration = double('integration user')
      allow(User).to receive(:integration).and_return(@integration)
      @cdefs = described_class.prep_custom_definitions([:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive])
    end
    it 'should reset lines that changed' do
      header_cdef = described_class.prep_custom_definitions([:ord_pc_approval_recommendation]).values.first
      @ord.update_custom_value!(header_cdef,'Approve')
      lines = [@ol1,@ol2]
      [:ordln_pc_approved_by,:ordln_pc_approved_by_executive].each do |uid|
        lines.each {|ln| ln.update_custom_value!(@cdefs[uid],@u.id)}
      end
      [:ordln_pc_approved_date,:ordln_pc_approved_date_executive].each do |uid|
        lines.each {|ln| ln.update_custom_value!(@cdefs[uid],Time.now)}
      end

      expect(order_data_klass).to receive(:lines_needing_pc_approval_reset).with(@od,@nd).and_return ['1']
      expect(@ord).to receive(:create_snapshot).with(@integration, nil, "System Job: Order Change Comparator")

      expect(described_class.reset_product_compliance_approvals(@ord,@od,@nd)).to be_truthy

      @ol1.reload
      @ol2.reload
      @cdefs.values.each do |cd|
        expect(@ol1.get_custom_value(cd).value).to be_blank
        expect(@ol2.get_custom_value(cd).value).to_not be_blank
      end

      @ord.reload
      expect(@ord.custom_value(header_cdef)).to be_blank

    end
    it 'should return false if lines changed but they were not approved' do
      expect(order_data_klass).to receive(:lines_needing_pc_approval_reset).with(@od,@nd).and_return ['1']
      expect(@ord).not_to receive(:create_snapshot)

      expect(described_class.reset_product_compliance_approvals(@ord,@od,@nd)).to be_falsey

    end
    it 'should return false if no lines changed' do
      [:ordln_pc_approved_by,:ordln_pc_approved_by_executive].each do |uid|
        @ol1.update_custom_value!(@cdefs[uid],@u.id)
      end
      [:ordln_pc_approved_date,:ordln_pc_approved_date_executive].each do |uid|
        @ol1.update_custom_value!(@cdefs[uid],Time.now)
      end

      expect(order_data_klass).to receive(:lines_needing_pc_approval_reset).with(@od,@nd).and_return []
      expect(@ord).not_to receive(:create_snapshot)

      expect(described_class.reset_product_compliance_approvals(@ord,@od,@nd)).to be_falsey

      @cdefs.values.each do |cd|
        expect(@ol1.get_custom_value(cd).value).to_not be_blank
      end
    end
  end

  describe '#create_pdf' do
    before :each do
      @o = double('order')
      @od = double('old_data')
      @nd = double('new_data')
      @integration = double('integration user')
      allow(User).to receive(:integration).and_return(@integration)
      @k = OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator
    end
    it 'should create pdf if OrderData#needs_new_pdf?' do
      expect(order_data_klass).to receive(:needs_new_pdf?).with(@od,@nd).and_return true
      expect(@k).to receive(:create!).with(@o,@integration)
      expect(described_class.create_pdf(@o,@od,@nd)).to be_truthy
    end
    it 'should not create pdf if !OrderData#needs_new_pdf?' do
      expect(order_data_klass).to receive(:needs_new_pdf?).with(@od,@nd).and_return false
      expect(@k).not_to receive(:create!)
      expect(described_class.create_pdf(@o,@od,@nd)).to be_falsey
    end
  end

  describe 'OrderData' do
    describe '#build_from_hash' do
      before :each do
        @cdefs = described_class.prep_custom_definitions([:ord_country_of_origin,:ord_sap_extract])
        # constant is loaded with custom definition model field IDs which change
        # each run in test because the CustomDefinitions are regenerated, so we
        # manually clear it. No need to do this in dev/production.
        described_class::OrderData::ORDER_CUSTOM_FIELDS.clear
      end
      it 'should create order data from hash' do
        p = Factory(:product,unique_identifier:'px')
        variant = Factory(:variant,product:p,variant_identifier:'VIDX')
        ol = Factory(:order_line,line_number:1,product:p,variant:variant,quantity:10,unit_of_measure:'EA',price_per_unit:5)
        Factory(:order_line,order:ol.order,line_number:2,product:p,quantity:50,unit_of_measure:'FT',price_per_unit:7)
        o = ol.order
        o.update_attributes(order_number:'ON1',
        ship_window_start:Date.new(2015,1,1),
        ship_window_end:Date.new(2015,1,10),
        currency:'USD',
        terms_of_payment:'NT30',
        terms_of_sale:'FOB',
        fob_point:'Shanghai'
        )
        o.update_custom_value!(@cdefs[:ord_country_of_origin],'CN')
        sap_extract = Time.now.utc
        o.update_custom_value!(@cdefs[:ord_sap_extract],sap_extract)
        o.reload

        expected_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN~~1~px~10.0~EA~5.0~~2~px~50.0~FT~7.0"

        h = JSON.parse(CoreModule::ORDER.entity_json(o))

        od = order_data_klass.build_from_hash(h)
        expect(od.fingerprint).to eq expected_fingerprint
        expected_variant_map = {1=>variant.variant_identifier,2=>nil}
        expect(od.variant_map).to eq expected_variant_map
        expected_price_map = {1=>"5.0",2=>"7.0"}
        expect(od.price_map).to eq expected_price_map
        expect(od.sap_extract_date.to_i).to eq sap_extract.to_i
        expect(od.ship_window_start).to eq '2015-01-01'
        expect(od.ship_window_end).to eq '2015-01-10'
      end
    end

    describe '#lines_with_changed_price' do
      it "should return lines added" do
        od = order_data_klass.new('fingerprint')
        od.price_map = {1=>5,2=>7}
        nd = order_data_klass.new('fingerprint')
        nd.price_map = {1=>5,2=>7,3=>2}
        expect(order_data_klass.lines_with_changed_price(od,nd)).to eq [3]
      end
      it "should return lines changed" do
        od = order_data_klass.new('fingerprint')
        od.price_map = {1=>5,2=>7}
        nd = order_data_klass.new('fingerprint')
        nd.price_map = {1=>5,2=>4}
        expect(order_data_klass.lines_with_changed_price(od,nd)).to eq [2]
      end
    end

    describe '#has_blank_defaults?' do
      it 'should be false if none of the fields defaulted from the vendor are blank' do
        fp = 'ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN'
        expect(order_data_klass.new(fp).has_blank_defaults?).to be_falsey
      end
      it 'should be true if ship terms are blank' do
        fp = 'ON1~2015-01-01~2015-01-10~USD~NT30~~Shanghai~CN'
        expect(order_data_klass.new(fp).has_blank_defaults?).to be_truthy
      end
      it 'should be true if fob point is blank' do
        fp = 'ON1~2015-01-01~2015-01-10~USD~NT30~FOB~~CN'
        expect(order_data_klass.new(fp).has_blank_defaults?).to be_truthy
      end
      it 'should be true if country of origin is blank' do
        fp = 'ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~'
        expect(order_data_klass.new(fp).has_blank_defaults?).to be_truthy
      end
    end

    describe '#vendor_approval_reset_fields_changed?' do
      it 'should return true if fingerprints are different' do
        od = double(:od)
        nd = double(:nd)
        [od,nd].each_with_index {|d,i| allow(d).to receive(:fingerprint).and_return(i.to_s)}
        expect(order_data_klass.vendor_approval_reset_fields_changed?(od,nd)).to be_truthy
      end
      it 'should return false if fingerprints are the same' do
        od = double(:od)
        nd = double(:nd)
        [od,nd].each {|d| allow(d).to receive(:fingerprint).and_return('x')}
        expect(order_data_klass.vendor_approval_reset_fields_changed?(od,nd)).to be_falsey
      end
      it 'should return false if old_data is nil' do
        nd = double(:nd)
        expect(order_data_klass.vendor_approval_reset_fields_changed?(nil,nd)).to be_falsey
      end
    end

    describe '#lines_needing_pc_approval_reset' do
      it 'should return lines in both hashes with different key values' do
        old_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN~~1~px~10.0~EA~5.0~~2~px~50.0~FT~7.0~~3~px~50.0~FT~7.0"
        old_data = order_data_klass.new(old_fingerprint)
        old_data.ship_from_address = 'abc'
        old_data.variant_map = {1=>'10',2=>'11'}
        new_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN~~1~px~10.0~EA~5.0~~2~px~22.0~FT~7.0~~4~px~50.0~FT~7.0"
        new_data = order_data_klass.new(new_fingerprint)
        new_data.ship_from_address = old_data.ship_from_address
        new_data.variant_map = old_data.variant_map
        # don't return line 1 because it stayed the same
        # don't return line 3 because it was deleted
        # don't return line 4 because it was added
        expect(order_data_klass.lines_needing_pc_approval_reset(old_data,new_data)).to eq ['2']
      end
      it 'should return all lines in new fingerprint if ship from address changed' do
        old_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN~~1~px~10.0~EA~5.0~~2~px~50.0~FT~7.0~~3~px~50.0~FT~7.0"
        old_data = order_data_klass.new(old_fingerprint)
        old_data.ship_from_address = 'abc'
        old_data.variant_map = {1=>'10',2=>'11'}
        new_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN~~1~px~10.0~EA~5.0~~2~px~22.0~FT~7.0~~4~px~50.0~FT~7.0"
        new_data = order_data_klass.new(new_fingerprint)
        new_data.ship_from_address = 'other'
        new_data.variant_map = old_data.variant_map
        expect(order_data_klass.lines_needing_pc_approval_reset(old_data,new_data)).to eq ['1','2','4']
      end
      it 'should not return lines where the only change to the ship from address is whitespace' do
        old_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN~~1~px~10.0~EA~5.0~~2~px~50.0~FT~7.0~~3~px~50.0~FT~7.0"
        old_data = order_data_klass.new(old_fingerprint)
        old_data.ship_from_address = 'abc def'
        old_data.variant_map = {'1'=>'10','2'=>'11'}
        new_data = order_data_klass.new(old_fingerprint)
        new_data.ship_from_address = " ab c\nde\r\nf"
        new_data.variant_map = old_data.variant_map.clone
        expect(order_data_klass.lines_needing_pc_approval_reset(old_data,new_data)).to eq []
      end
      it 'should return lines with different variants' do
        old_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN~~1~px~10.0~EA~5.0~~2~px~50.0~FT~7.0~~3~px~50.0~FT~7.0"
        old_data = order_data_klass.new(old_fingerprint)
        old_data.ship_from_address = 'abc'
        old_data.variant_map = {'1'=>'10','2'=>'11'}
        new_data = order_data_klass.new(old_fingerprint)
        new_data.ship_from_address = old_data.ship_from_address
        new_data.variant_map = {'1'=>'OTHER','2'=>'11','3'=>'NEW'}
        expect(order_data_klass.lines_needing_pc_approval_reset(old_data,new_data)).to eq ['1','3']
      end
    end

    describe '#needs_new_pdf?' do
      before :each do
        @od = double('old_data')
        @nd = double('new_data')
      end
      it 'should return true if fingerprints are different' do
        [@od,@nd].each_with_index {|d,i| allow(d).to receive(:fingerprint).and_return(i.to_s); allow(d).to receive(:ship_from_address).and_return('sf')}
        expect(order_data_klass.needs_new_pdf?(@od,@nd)).to be_truthy
      end
      it 'should return true if ship from addresses are different' do
        [@od,@nd].each_with_index {|d,i| allow(d).to receive(:fingerprint).and_return('x'); allow(d).to receive(:ship_from_address).and_return(i.to_s)}
        expect(order_data_klass.needs_new_pdf?(@od,@nd)).to be_truthy
      end
      it 'should return true if old_data is nil' do
        expect(order_data_klass.needs_new_pdf?(nil,@nd)).to be_truthy
      end
      it 'should return false if fingerprints are the same and the ship from addresss are the same' do
        [@od,@nd].each {|d,i| allow(d).to receive(:fingerprint).and_return('x'); allow(d).to receive(:ship_from_address).and_return('sf')}
        expect(order_data_klass.needs_new_pdf?(@od,@nd)).to be_falsey
      end
    end
  end

end

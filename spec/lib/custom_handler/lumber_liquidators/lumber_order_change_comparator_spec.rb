require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator do
  subject { described_class }
  let :order_data_klass do
    described_class::OrderData
  end

  before :each do 
    allow(Lock).to receive(:with_lock_retry).and_yield
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
    let (:order_id) { 1 }
    let (:order) {
      o = instance_double(Order)
      allow(o).to receive(:reload)
      allow(Order).to receive(:find_by_id).with(order_id).and_return o
      o
    }
    let (:old_data) { instance_double(described_class::OrderData) }
    let (:new_data) { instance_double(described_class::OrderData) }

    before :each do
      # stub all business logic methods, then in each test we use should_receive for the one we're testing
      allow(subject).to receive(:set_defaults).and_return false
      allow(subject).to receive(:clear_planned_handover_date).and_return false
      allow(subject).to receive(:set_forecasted_handover_date).and_return false
      allow(subject).to receive(:update_autoflow_approvals).and_return false
      allow(subject).to receive(:reset_vendor_approvals).and_return false
      allow(subject).to receive(:reset_product_compliance_approvals).and_return false
      allow(subject).to receive(:set_price_revised_dates).and_return false
      allow(subject).to receive(:generate_ll_xml)
      allow(subject).to receive(:reset_po_cancellation).and_return false
      allow(subject).to receive(:create_pdf).and_return false
      allow(subject).to receive(:update_change_log).and_return false
    end
    it 'should return if order does not exist' do
      allow(Order).to receive(:find_by_id).and_return nil
      expect(subject).not_to receive(:set_defaults)
      expect(subject.execute_business_logic(1, old_data, new_data)).to be_falsey
    end
    it 'should set defaults' do
      expect(subject).to receive(:set_defaults).with(order, new_data).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Order Default Value Setter"
      subject.execute_business_logic(1, old_data, new_data)
    end
    it 'should clear planned handover date' do
      expect(subject).to receive(:clear_planned_handover_date).with(order,old_data,new_data).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Clear Planned Handover"
      subject.execute_business_logic(1,old_data,new_data)
    end
    it 'should set forecasted handover date' do
      expect(subject).to receive(:set_forecasted_handover_date).with(order).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Forecasted Window Update"
      subject.execute_business_logic(1,old_data,new_data)
    end
    it 'should reset vendor approvals' do
      expect(subject).to receive(:reset_vendor_approvals).with(order,old_data,new_data).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Vendor Approval Reset"
      subject.execute_business_logic(1,old_data,new_data)
    end
    it 'should reset PC / Exec PC approvals' do
      expect(subject).to receive(:reset_product_compliance_approvals).with(order,old_data,new_data).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Compliance Approval Reset"
      subject.execute_business_logic(1,old_data,new_data)
    end
    it 'should set price revised dates' do
      expect(subject).to receive(:set_price_revised_dates).with(order,old_data,new_data).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Update Price Revised Dates"
      subject.execute_business_logic(1,old_data,new_data)
    end
    it 'should autoflow' do
      expect(subject).to receive(:update_autoflow_approvals).with(order).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Autoflow Order Approver"
      subject.execute_business_logic(1,old_data,new_data)
    end
    it 'should reset PO cancellation' do
      expect(subject).to receive(:reset_po_cancellation).with(order).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: PO Cancellation Reset"
      subject.execute_business_logic(1,old_data,new_data)
    end
    it 'should generate new PDF if values were updated' do
      allow(subject).to receive(:set_defaults).and_return true
      expect(subject).to receive(:create_pdf).with(order,old_data,new_data)
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Order Default Value Setter"
      subject.execute_business_logic(1,old_data,new_data)
    end
    it 'should not generate new PDF if no values were updated' do
      allow(subject).to receive(:set_defaults).and_return false
      expect(subject).not_to receive(:create_pdf)
      subject.execute_business_logic(1,old_data,new_data)
    end
    it 'should generate xml' do
      expect(subject).to receive(:generate_ll_xml).with(order,old_data,new_data).and_return true
      subject.execute_business_logic(1,old_data,new_data)
    end
    it 'should update change log' do
      expect(subject).to receive(:update_change_log).with(order,old_data,new_data).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Change Log"
      subject.execute_business_logic(1,old_data,new_data)
    end

    it "allows specifying exact logic rules to run" do
      expect(subject).to receive(:set_defaults).with(order, new_data).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Order Default Value Setter"
      expect(subject).to receive(:generate_ll_xml).with(order,old_data,new_data).and_return true

      subject.execute_business_logic(1,old_data,new_data, [:set_defaults, :generate_ll_xml])
    end

    it "appends all logic rule names that modified data to snapshot context" do
      expect(subject).to receive(:set_defaults).with(order, new_data).and_return true
      expect(subject).to receive(:update_autoflow_approvals).with(order).and_return true
      expect(order).to receive(:create_snapshot).with User.integration, nil, "System Job: Order Change Comparator: Order Default Value Setter / Autoflow Order Approver"
      subject.execute_business_logic(1,old_data,new_data)
    end

    it "removes approvals from logic list if approval resets are disabled" do
      expect(subject).to receive(:disable_approval_resets?).and_return true
      order
      expect(subject).not_to receive(:reset_vendor_approvals)
      expect(subject).not_to receive(:reset_product_compliance_approvals)


      subject.execute_business_logic(1,old_data,new_data)
    end
  end

  describe '#set_price_revised_dates' do
    let (:order) {
      order = Factory(:order_line,line_number:1).order
      expect(order).not_to receive(:snapshot)
      order
    }
    let (:cdefs) { subject.prep_custom_definitions([:ord_sap_extract,:ord_price_revised_date,:ordln_price_revised_date]) }
    let (:extract_timestamp) { Time.zone.now }

    it "should do nothing if price didn't change" do
      od = double('old_data')
      nd = double('new_data')
      allow(nd).to receive(:sap_extract_date).and_return extract_timestamp
      expect(order_data_klass).to receive(:lines_with_changed_price).with(od,nd).and_return []
      expect(subject.set_price_revised_dates(order,od,nd)).to be_falsey
      o = Order.find order.id
      expect(o.custom_value(cdefs[:ord_price_revised_date])).to be_nil
      expect(o.order_lines.first.custom_value(cdefs[:ordln_price_revised_date])).to be_nil
    end
    it "should update if price on existing line changed" do
      od = double('old_data')
      nd = double('new_data')
      expect(nd).to receive(:sap_extract_date).and_return extract_timestamp
      expect(order_data_klass).to receive(:lines_with_changed_price).with(od,nd).and_return [1]
      expect(subject.set_price_revised_dates(order,od,nd)).to be_truthy
      o = Order.find order.id
      expect(o.custom_value(cdefs[:ord_price_revised_date]).to_i).to eq extract_timestamp.to_i
      expect(o.order_lines.first.custom_value(cdefs[:ordln_price_revised_date]).to_i).to eq extract_timestamp.to_i
    end
  end

  describe '#clear_planned_handover_date' do
    let (:order) { 
      order = Factory(:order)
      order.update_custom_value!(cdefs[:ord_planned_handover_date],Date.new(2016,10,1))
      order
      expect(order).not_to receive(:create_snapshot)
      order
    }

    let (:cdefs) { described_class.prep_custom_definitions([:ord_planned_handover_date]) }

    def base_data dates=[Date.new(2016,8,15),Date.new(2016,9,1)]
      data = double(:data)
      allow(data).to receive(:ship_window_start).and_return dates[0]
      allow(data).to receive(:ship_window_end).and_return dates[1]
      data
    end

    it "should clear planned handover date if ship window start changes" do
      old_data = base_data
      new_data = base_data([Date.new(2016,8,10),Date.new(2016,9,1)])
      expect(subject.clear_planned_handover_date(order,old_data,new_data)).to be_truthy
      order.reload
      expect(order.custom_value(cdefs[:ord_planned_handover_date])).to be_blank
    end
    it "should clear planned handover date if ship window end changes" do
      old_data = base_data
      new_data = base_data([Date.new(2016,8,15),Date.new(2016,9,10)])
      expect(subject.clear_planned_handover_date(order,old_data,new_data)).to be_truthy
      order.reload
      expect(order.custom_value(cdefs[:ord_planned_handover_date])).to be_blank
    end
    it "should not clear if ship window stays the same" do
      old_data = base_data
      new_data = base_data
      expect(subject.clear_planned_handover_date(order,old_data,new_data)).to be_falsey
      order.reload
      expect(order.custom_value(cdefs[:ord_planned_handover_date])).to_not be_blank
    end
    it "should return immediately if planned_handover_date is empty" do
      order.update_custom_value!(cdefs[:ord_planned_handover_date],nil)
      old_data = base_data
      new_data = base_data([Date.new(2016,8,15),Date.new(2016,9,10)])
      expect(described_class.clear_planned_handover_date(order,old_data,new_data)).to be_falsey
      order.reload
      expect(order.custom_value(cdefs[:ord_planned_handover_date])).to be_blank
    end
  end

  describe '#set_forecasted_handover_date' do
    # PER SOW 1100 (2016-11-04), Forecasted Handover Date is being relabelled as Forecasted Ship Window End, but we're leaving the variables in the code alone
    # all tests also confirm that forecasted ship window start is set to 7 days prior to forecasted handover date
    let (:cdefs) { described_class.prep_custom_definitions([:ord_forecasted_handover_date,:ord_planned_handover_date,:ord_forecasted_ship_window_start]) }
    let (:order) { Factory(:order,ship_window_end:Date.new(2016,5,10)) }
     
    it "should set forecasted handover date to planned_handover_date if planned_handover_date is not blank" do
      order.update_custom_value!(cdefs[:ord_planned_handover_date],Date.new(2016,5,15))
      expect(subject.set_forecasted_handover_date(order)).to eq true
      expect(order.custom_value(cdefs[:ord_forecasted_handover_date])).to eq Date.new(2016,5,15)
      expect(order.custom_value(cdefs[:ord_forecasted_ship_window_start])).to eq Date.new(2016,5,8)
    end
    it "should set forecasted handover date to ship_window_end if planned_handover_date is blank" do
      expect(subject.set_forecasted_handover_date(order)).to eq true
      expect(order.custom_value(cdefs[:ord_forecasted_handover_date])).to eq Date.new(2016,5,10)
      expect(order.custom_value(cdefs[:ord_forecasted_ship_window_start])).to eq Date.new(2016,5,3)
    end
    it "should return false if did not change" do
      order.update_custom_value!(cdefs[:ord_forecasted_handover_date],Date.new(2016,5,10))
      expect(subject.set_forecasted_handover_date(order)).to eq false
      order.reload
      expect(order.custom_value(cdefs[:ord_forecasted_handover_date])).to eq Date.new(2016,5,10)
    end
  end

  describe '#generate ll xml' do
    ["NB", "ZMSP"].each do |type|
      it "should send xml if OrderData.send_sap_update? returns true and type is #{type}" do
        o = instance_double(Order)
        expect(o).to receive(:id).and_return 10

        od = double('OrderData-Old')
        nd = double('OrderData-New')
        allow(nd).to receive(:order_type).and_return type
        expect(BusinessValidationTemplate).to receive(:create_results_for_object!).with o, snapshot_entity: false
        expect(order_data_klass).to receive(:send_sap_update?).with(o, od,nd).and_return true
        now = Time.zone.now
        expect(OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator).to receive(:delay).with(run_at: (now + 5.minutes), priority: 20).and_return OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator
        expect(OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator).to receive(:delayed_send_order).with(10)

        Timecop.freeze(now) { subject.generate_ll_xml(o,od,nd) }
      end
    end
    
    context "with disabled delayed jobs", :disable_delayed_jobs do 
      it 'should not send xml if OrderData.send_sap_update? returns false' do
        o = double('order')
        od = double('OrderData-Old')
        nd = double('OrderData-New')
        allow(nd).to receive(:order_type).and_return "NB"
        expect(order_data_klass).to receive(:send_sap_update?).with(o, od,nd).and_return false
        expect(OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator).not_to receive(:delayed_send_order)
        subject.generate_ll_xml(o,od,nd)
      end

      it "should not send xml if order type is not 'NB' or 'ZMSP'" do
        nd = double('OrderData-New')
        allow(nd).to receive(:order_type).and_return "SOME OTHER TYPE"
        expect(OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator).not_to receive(:delayed_send_order)
        subject.generate_ll_xml(nil,nil,nd)
      end
    end
  end

  describe '#set_defaults' do
    let (:k) { OpenChain::CustomHandler::LumberLiquidators::LumberOrderDefaultValueSetter }

    it 'should call if order_data#has_blank_defaults?' do
      o = double('order')
      d = double('OrderData')
      expect(d).to receive(:has_blank_defaults?).and_return true
      expect(k).to receive(:set_defaults).with(o, entity_snapshot: false).and_return true
      expect(described_class.set_defaults(o,d)).to be_truthy
    end
    it 'should return false if has_blank_defaults? but nothing is changed' do
      o = double('order')
      d = double('OrderData')
      expect(d).to receive(:has_blank_defaults?).and_return true
      expect(k).to receive(:set_defaults).with(o, entity_snapshot: false).and_return false
      expect(described_class.set_defaults(o,d)).to be_falsey
    end
    it 'should not call if !order_data#has_blank_defaults?' do
      o = double('order')
      d = double('OrderData')
      expect(d).to receive(:has_blank_defaults?).and_return false
      expect(k).not_to receive(:set_defaults)
      expect(described_class.set_defaults(o,d)).to be_falsey
    end

  end

  describe 'reset_po_cancellation' do
    let (:cdef) { described_class.prep_custom_definitions([:ord_cancel_date])[:ord_cancel_date] }
    let (:order) { 
      order = Factory(:order, closed_at: nil)
      order.update_custom_value! cdef, nil
      order
    }

    it "reopens and uncancels order if it has lines and a cancel date, returns 'true'" do
      Factory(:order_line, order: order)
      order.update_custom_value! cdef, Date.today
      order.update_attributes(closed_at: DateTime.now)

      expect(subject.reset_po_cancellation order).to eq true
      cancel_date = order.get_custom_value cdef
      expect(cancel_date.value).to be_nil
      expect(order.closed_at).to be_nil
    end

    it "closes and cancels order if it is doesn't have lines or a cancel date, returns true" do
      expect(described_class.reset_po_cancellation order).to eq true
      cancel_date = order.get_custom_value cdef
      expect(cancel_date.value).not_to be_nil
      expect(order.closed_at).not_to be_nil
    end

    it "makes no change if order has lines but no cancel date, returns 'false'" do
      closed = DateTime.now - 10
      order.update_attributes(closed_at: closed)
      Factory(:order_line, order: order)
      expect(described_class.reset_po_cancellation order).to eq false
      cancel_date = order.get_custom_value cdef
      expect(cancel_date.value).to be_nil
      expect(order.closed_at).to eq closed
    end

    it "makes no change if order has a cancel date and no lines, returns 'false'" do
      closed = DateTime.now - 10
      order.update_attributes(closed_at: closed)
      order.update_custom_value! cdef, Date.today
      expect(described_class.reset_po_cancellation order).to eq false
      cancel_date = order.get_custom_value cdef
      expect(cancel_date.value).to eq Date.today
      expect(order.closed_at).to eq closed
    end
  end

  describe '#update_autoflow_approvals' do
    it 'should call AutoFlowApprover' do
      o = double('order')
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover).to receive(:process).with(o, entity_snapshot: false).and_return true
      expect(subject.update_autoflow_approvals(o)).to be_truthy
    end
    it 'should return value of AutoFlowApprover' do
      o = double('order')
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover).to receive(:process).with(o, entity_snapshot: false).and_return false
      expect(subject.update_autoflow_approvals(o)).to be_falsey
    end
  end

  describe '#reset_vendor_approvals' do
    let (:nd) { instance_double(described_class::OrderData) }
    let (:od) { instance_double(described_class::OrderData) }
    let (:order) { instance_double(Order) }
    let (:user) { 
      u = instance_double(User)
      allow(User).to receive(:integration).and_return u
      u
    }
    it 'should reset if OrderData#vendor_approval_reset_fields_changed? and order is accepted' do
      expect(order_data_klass).to receive(:vendor_approval_reset_fields_changed?).with(od, nd).and_return true
      expect(order).to receive(:approval_status).and_return 'Accepted'
      expect(order).to receive(:unaccept!).with(user)
      expect(subject.reset_vendor_approvals(order,od, nd)).to be_truthy
    end
    it 'should not reset if !OrderData#vendor_approval_reset_fields_changed?' do
      expect(order_data_klass).to receive(:vendor_approval_reset_fields_changed?).with(od, nd).and_return false
      expect(order).not_to receive(:unaccept!)
      expect(subject.reset_vendor_approvals(order,od, nd)).to be_falsey
    end
    it 'should not reset if OrderData#vendor_approval_reset_fields_changed? && order not accepted' do
      expect(order_data_klass).to receive(:vendor_approval_reset_fields_changed?).with(od, nd).and_return true
      expect(order).to receive(:approval_status).and_return ''
      expect(order).not_to receive(:unaccept!)
      expect(subject.reset_vendor_approvals(order,od, nd)).to be_falsey
    end
  end

  describe '#reset_product_compliance_approvals' do
    let (:nd) { instance_double(described_class::OrderData) }
    let (:od) { instance_double(described_class::OrderData) }
    let! (:order) { Factory(:order) }
    let! (:line1) { Factory(:order_line,order:order,line_number:'1') }
    let! (:line2) { Factory(:order_line,order:order,line_number:'2') }
    let (:user) { 
      u = Factory(:user)
      allow(User).to receive(:integration).and_return u
      u
    }
    let (:cdefs) { described_class.prep_custom_definitions([:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive]) }
    
    before :each do 
      order.reload
    end

    it 'should reset lines that changed' do
      header_cdef = described_class.prep_custom_definitions([:ord_pc_approval_recommendation]).values.first
      order.update_custom_value!(header_cdef,'Approve')
      lines = [line1, line2]
      [:ordln_pc_approved_by,:ordln_pc_approved_by_executive].each do |uid|
        lines.each {|ln| ln.update_custom_value!(cdefs[uid], user.id)}
      end
      [:ordln_pc_approved_date,:ordln_pc_approved_date_executive].each do |uid|
        lines.each {|ln| ln.update_custom_value!(cdefs[uid],Time.now)}
      end

      expect(order_data_klass).to receive(:lines_needing_pc_approval_reset).with(od, nd).and_return ['1']

      expect(subject.reset_product_compliance_approvals(order,od, nd)).to be_truthy

      [order, line1, line2].each &:reload

      cdefs.values.each do |cd|
        expect(line1.custom_value(cd)).to be_blank
        expect(line2.custom_value(cd)).to_not be_blank
      end

      expect(order.custom_value(header_cdef)).to be_blank

    end
    it 'should return false if lines changed but they were not approved' do
      expect(order_data_klass).to receive(:lines_needing_pc_approval_reset).with(od, nd).and_return ['1']
      expect(subject.reset_product_compliance_approvals(order,od, nd)).to be_falsey
    end

    it 'should return false if no lines changed' do
      [:ordln_pc_approved_by,:ordln_pc_approved_by_executive].each do |uid|
        line1.update_custom_value!(cdefs[uid],user.id)
      end
      [:ordln_pc_approved_date,:ordln_pc_approved_date_executive].each do |uid|
        line1.update_custom_value!(cdefs[uid],Time.now)
      end

      expect(order_data_klass).to receive(:lines_needing_pc_approval_reset).with(od, nd).and_return []

      expect(subject.reset_product_compliance_approvals(order,od, nd)).to be_falsey

      cdefs.values.each do |cd|
        expect(line1.custom_value(cd)).to_not be_blank
      end
    end
  end

  describe '#create_pdf' do
    let (:nd) { instance_double(described_class::OrderData) }
    let (:od) { instance_double(described_class::OrderData) }
    let (:order) { instance_double(Order) }
    let (:user) { 
      u = Factory(:user)
      allow(User).to receive(:integration).and_return u
      u
    }
    let (:k) { OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator }

    it 'should create pdf if OrderData#vendor_visible_fields_changed?' do
      expect(order_data_klass).to receive(:vendor_visible_fields_changed?).with(od, nd).and_return true
      expect(k).to receive(:create!).with(order, user)
      expect(described_class.create_pdf(order,od, nd)).to be_truthy
    end
    it 'should not create pdf if !OrderData#vendor_visible_fields_changed?' do
      expect(order_data_klass).to receive(:vendor_visible_fields_changed?).with(od, nd).and_return false
      expect(k).not_to receive(:create!)
      expect(described_class.create_pdf(order, od, nd)).to be_falsey
    end
  end

  describe '#update_change_log' do
    let :cdefs do
      described_class.prep_custom_definitions [:ord_country_of_origin,:ord_change_log]
    end
    let :fingerprint_hash do
      {
        'ord_ord_num' => 'ON1',
        'ord_window_start' => '2015-01-01',
        'ord_window_end' => '2015-01-10',
        'ord_currency' => 'USD',
        'ord_payment_terms' => 'NT30',
        'ord_terms' => 'FOB',
        'ord_fob_point' => 'Shanghai',
        cdefs[:ord_country_of_origin].model_field_uid.to_s => 'CN',
        'lines' => {
          '1' => {
            'ordln_line_number' => 1,
            'ordln_puid' => 'px',
            'ordln_ordered_qty' => '10.0',
            'ordln_unit_of_measure' => 'EA',
            'ordln_ppu' => '5.0'
          },
          '2' => {
            'ordln_line_number' => 2,
            'ordln_puid' => 'px',
            'ordln_ordered_qty' => '50.0',
            'ordln_unit_of_measure' => 'FT',
            'ordln_ppu' => '7.0'
          }
        }
      }
    end
    let :order do
      double('order')
    end
    let :old_data do
      double('old_data')
    end
    let :new_data do
      double('new_data')
    end
    it "should do nothing if !vendor_visible_fields_changed?" do
      expect(described_class::OrderData).to receive(:vendor_visible_fields_changed?).with(old_data,new_data).and_return false
      described_class.update_change_log(order,old_data,new_data)
      # no assertions because nothing should happen and doubles will fail if methods are called
    end
    it "should do nothing on first snapshot" do
      expect(described_class::OrderData).to_not receive(:vendor_visible_fields_changed?)
      described_class.update_change_log(order,nil,new_data)
      # no assertions because nothing should happen and doubles will fail if methods are called
    end
    it "should append changed header fields to change log" do
      Timecop.freeze do
        expect(described_class::OrderData).to receive(:vendor_visible_fields_changed?).with(old_data,new_data).and_return true
        old_hash = fingerprint_hash.clone
        new_hash = fingerprint_hash.clone
        new_hash['ord_terms'] = 'DDP'
        new_hash['ord_fob_point'] = 'Richmond'
        expect(old_data).to receive(:fingerprint_hash).and_return old_hash
        expect(new_data).to receive(:fingerprint_hash).and_return new_hash

        expected_values = [
          "#{0.seconds.ago.utc.strftime('%Y-%m-%d %H:%M')} (UTC):\n",
          "\t#{ModelField.find_by_uid(:ord_terms).label} changed from \"FOB\" to \"DDP\"\n",
          "\t#{ModelField.find_by_uid(:ord_fob_point).label} changed from \"Shanghai\" to \"Richmond\"\n"
        ]
        expect(order).to receive(:custom_value).with(cdefs[:ord_change_log]).and_return ""
        expect(order).to receive(:update_custom_value!) do |cdef,new_val|
          expect(cdef).to eq cdefs[:ord_change_log]
          nva = new_val.lines.delete_if {|ln| ln=="\n"}

          # first line must be first, and the remaining lines can be in any order
          # so we test by resorting them an checking array equality.
          expect(nva[0]).to eq expected_values[0]
          expect(nva.sort).to eq expected_values.sort
        end
        described_class.update_change_log(order,old_data,new_data)
      end
    end
    it "should note added line" do
      Timecop.freeze do
        expect(described_class::OrderData).to receive(:vendor_visible_fields_changed?).with(old_data,new_data).and_return true
        old_hash = fingerprint_hash.clone
        old_hash['lines'] = old_hash['lines'].clone
        old_hash['lines'].delete('1')
        new_hash = fingerprint_hash.clone
        expect(old_data).to receive(:fingerprint_hash).and_return old_hash
        expect(new_data).to receive(:fingerprint_hash).and_return new_hash

        expected_values = [
          "#{0.seconds.ago.utc.strftime('%Y-%m-%d %H:%M')} (UTC):\n",
          "\tAdded line number 1\n",
        ]
        expect(order).to receive(:custom_value).with(cdefs[:ord_change_log]).and_return ""
        expect(order).to receive(:update_custom_value!) do |cdef,new_val|
          expect(cdef).to eq cdefs[:ord_change_log]
          nva = new_val.lines.delete_if {|ln| ln=="\n"}
          expect(nva).to eq expected_values
        end
        described_class.update_change_log(order,old_data,new_data)
      end
    end
    it "should note deleted line" do
      Timecop.freeze do
        expect(described_class::OrderData).to receive(:vendor_visible_fields_changed?).with(old_data,new_data).and_return true
        old_hash = fingerprint_hash.clone
        new_hash = fingerprint_hash.clone
        new_hash['lines'] = new_hash['lines'].clone
        new_hash['lines'].delete('1')
        expect(old_data).to receive(:fingerprint_hash).and_return old_hash
        expect(new_data).to receive(:fingerprint_hash).and_return new_hash

        expected_values = [
          "#{0.seconds.ago.utc.strftime('%Y-%m-%d %H:%M')} (UTC):\n",
          "\tRemoved line number 1\n",
        ]
        expect(order).to receive(:custom_value).with(cdefs[:ord_change_log]).and_return ""
        expect(order).to receive(:update_custom_value!) do |cdef,new_val|
          expect(cdef).to eq cdefs[:ord_change_log]
          nva = new_val.lines.delete_if {|ln| ln=="\n"}
          expect(nva).to eq expected_values
        end
        described_class.update_change_log(order,old_data,new_data)
      end
    end
    it "should note change in line field" do
      Timecop.freeze do
        expect(described_class::OrderData).to receive(:vendor_visible_fields_changed?).with(old_data,new_data).and_return true
        old_hash = fingerprint_hash.deep_dup
        new_hash = fingerprint_hash.deep_dup
        new_hash['lines']['1']['ordln_ppu'] = "77.4"
        expect(old_data).to receive(:fingerprint_hash).and_return old_hash
        expect(new_data).to receive(:fingerprint_hash).and_return new_hash

        expected_values = [
          "#{0.seconds.ago.utc.strftime('%Y-%m-%d %H:%M')} (UTC):\n",
          "\tLine 1\n",
          "\t\t#{ModelField.find_by_uid(:ordln_ppu).label} changed from \"5.0\" to \"77.4\"\n"
        ]
        expect(order).to receive(:custom_value).with(cdefs[:ord_change_log]).and_return ""
        expect(order).to receive(:update_custom_value!) do |cdef,new_val|
          expect(cdef).to eq cdefs[:ord_change_log]
          nva = new_val.lines.delete_if {|ln| ln=="\n"}
          expect(nva).to eq expected_values
        end
        described_class.update_change_log(order,old_data,new_data)
      end
    end
  end

  describe 'OrderData' do
    let :cdefs do
      described_class.prep_custom_definitions([:ord_country_of_origin,:ord_sap_extract, :ord_planned_handover_date, :ord_type, :ordln_custom_article_description, :ordln_vendor_inland_freight_amount])
    end
    let :sap_extract_date do
      Time.now.utc
    end
    let :base_order do
      p = Factory(:product,unique_identifier:'px')
      variant = Factory(:variant,product:p,variant_identifier:'VIDX')
      ol = Factory(:order_line,line_number:1,product:p,variant:variant,quantity:10,unit_of_measure:'EA',price_per_unit:5)
      ol2 = Factory(:order_line,order:ol.order,line_number:2,product:p,quantity:50,unit_of_measure:'FT',price_per_unit:7)
      o = ol.order
      o.update_attributes(order_number:'ON1',
      ship_window_start:Date.new(2015,1,1),
      ship_window_end:Date.new(2015,1,10),
      currency:'USD',
      terms_of_payment:'NT30',
      terms_of_sale:'FOB',
      fob_point:'Shanghai',
      approval_status:'Approved'
      )
      o.update_custom_value!(cdefs[:ord_country_of_origin],'CN')
      o.update_custom_value!(cdefs[:ord_sap_extract],sap_extract_date)
      o.update_custom_value!(cdefs[:ord_planned_handover_date], Date.new(2015, 2, 2))
      o.update_custom_value!(cdefs[:ord_type],'Type')
      ol.update_custom_value!(cdefs[:ordln_custom_article_description], 'Custom desc')
      ol.update_custom_value!(cdefs[:ordln_vendor_inland_freight_amount], 123.45)
      ol2.update_custom_value!(cdefs[:ordln_custom_article_description], 'Another custom desc')
      ol2.update_custom_value!(cdefs[:ordln_vendor_inland_freight_amount], 678.9)
      expect(o).to receive(:business_rules_state).and_return('Fail')
      o.reload
      o
    end
    let :coo_cdef_uid do
      cdefs[:ord_country_of_origin].model_field_uid.to_s
    end
    let :base_fingerprint_hash do
      {
        'ord_ord_num' => 'ON1',
        'ord_window_start' => '2015-01-01',
        'ord_window_end' => '2015-01-10',
        'ord_currency' => 'USD',
        'ord_payment_terms' => 'NT30',
        'ord_terms' => 'FOB',
        'ord_fob_point' => 'Shanghai',
        'lines' => {
          '1' => {
            'ordln_line_number' => 1,
            'ordln_puid' => 'px',
            'ordln_ordered_qty' => '10.0',
            'ordln_unit_of_measure' => 'EA',
            'ordln_ppu' => '5.0',
            cdefs[:ordln_custom_article_description].model_field_uid => 'Custom desc',
            cdefs[:ordln_vendor_inland_freight_amount].model_field_uid => '123.45'
          },
          '2' => {
            'ordln_line_number' => 2,
            'ordln_puid' => 'px',
            'ordln_ordered_qty' => '50.0',
            'ordln_unit_of_measure' => 'FT',
            'ordln_ppu' => '7.0',
            cdefs[:ordln_custom_article_description].model_field_uid => 'Another custom desc',
            cdefs[:ordln_vendor_inland_freight_amount].model_field_uid => '678.9'
          }
        }
      }
    end
    describe '#build_from_hash' do

      it 'should create order data from hash' do
        h = JSON.parse(CoreModule::ORDER.entity_json(base_order))

        od = order_data_klass.build_from_hash(h)
        expect(JSON.parse(od.fingerprint)).to eq base_fingerprint_hash
        variant = base_order.order_lines.first.product.variants.first
        expected_variant_map = {1=>variant.variant_identifier,2=>nil}
        expect(od.variant_map).to eq expected_variant_map
        expected_price_map = {1=>"5.0",2=>"7.0"}
        expect(od.price_map).to eq expected_price_map
        expect(od.sap_extract_date.to_i).to eq sap_extract_date.to_i
        expect(od.ship_window_start).to eq '2015-01-01'
        expect(od.ship_window_end).to eq '2015-01-10'
        expect(od.business_rule_state).to eq 'Fail'
        expect(od.approval_status).to eq 'Approved'
        expect(od.order_type).to eq "Type"
      end
    end

    describe '#lines_with_changed_price' do
      it "should return lines added" do
        od = order_data_klass.new(base_fingerprint_hash)
        od.price_map = {1=>5,2=>7}
        nd = order_data_klass.new(base_fingerprint_hash)
        nd.price_map = {1=>5,2=>7,3=>2}
        expect(order_data_klass.lines_with_changed_price(od,nd)).to eq [3]
      end
      it "should return lines changed" do
        od = order_data_klass.new(base_fingerprint_hash)
        od.price_map = {1=>5,2=>7}
        nd = order_data_klass.new(base_fingerprint_hash)
        nd.price_map = {1=>5,2=>4}
        expect(order_data_klass.lines_with_changed_price(od,nd)).to eq [2]
      end
    end

    describe '#has_blank_defaults?' do
      let :order_data do
        od = order_data_klass.new(base_fingerprint_hash)
        od.country_of_origin = 'CN'
        od
      end
      it 'should be false if none of the fields defaulted from the vendor are blank' do
        expect(order_data.has_blank_defaults?).to be_falsey
      end
      it 'should be true if ship terms are blank' do
        base_fingerprint_hash['ord_terms'] = ''
        expect(order_data.has_blank_defaults?).to be_truthy
      end
      it 'should be true if fob point is blank' do
        base_fingerprint_hash['ord_fob_point'] = ''
        expect(order_data.has_blank_defaults?).to be_truthy
      end
      it 'should be true if country of origin is blank' do
        order_data.country_of_origin = nil
        expect(order_data.has_blank_defaults?).to be_truthy
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

    describe '#send_sap_update?' do
      def make_data data_name
        r = double(data_name)
        allow(r).to receive(:approval_status).and_return ''
        allow(r).to receive(:business_rule_state).and_return 'Pass'
        allow(r).to receive(:planned_handover_date).and_return "2017-01-02"
        r
      end
      let (:order) {
        order = Factory(:order, approval_status: "")
        order.update_custom_value! handover_cdef, Date.new(2017,1,2)
        allow(order).to receive(:business_rules_state).and_return "Pass"
        order
      }

      let (:handover_uid) { 
        handover_cdef.model_field_uid
      }

      let (:handover_cdef) {
        described_class::OrderData.prep_custom_definitions([:ord_planned_handover_date])[:ord_planned_handover_date]
      }

      before :each do
        allow(described_class::OrderData).to receive(:planned_handover_date_uid).and_return handover_uid
      end

      it 'should return false if no changes' do
        nd = make_data('new-data')
        od = make_data('old-data')
        expect(order_data_klass.send_sap_update?(order, od,nd)).to eq false
      end

      it 'should return true if old_data is nil' do
        nd = make_data('new-data')
        expect(order_data_klass.send_sap_update?(order, nil,nd)).to eq true
      end
      it 'should return true if approval status changed' do
        nd = make_data('new-data')
        od = make_data('old-data')
        expect(od).to receive(:approval_status).and_return 'Approved'
        expect(order_data_klass.send_sap_update?(order, od,nd)).to eq true
      end

      it "should return true if approval status has been updated in order object" do
        nd = make_data('new-data')
        od = make_data('old-data')
        order.approval_status = "Pass"
        expect(order_data_klass.send_sap_update?(order, od,nd)).to eq true
      end

      it 'should return true if business rule state changed' do
        nd = make_data('new-data')
        od = make_data('old-data')
        expect(od).to receive(:business_rule_state).and_return 'Fail'
        expect(order_data_klass.send_sap_update?(order, od,nd)).to eq true
      end

      it "should return true if business rule state changes in the order" do
        nd = make_data('new-data')
        od = make_data('old-data')
        expect(od).to receive(:business_rule_state).and_return 'Fail'
        expect(nd).to receive(:business_rule_state).and_return 'Fail'
        expect(order).to receive(:business_rules_state).and_return "Pass"
        expect(order_data_klass.send_sap_update?(order, od,nd)).to eq true
      end

      it 'should return true if planned handover date changed' do
        nd = make_data('new-data')
        od = make_data('old-data')
        expect(od).to receive(:planned_handover_date).and_return "2017-01-03"
        expect(order_data_klass.send_sap_update?(order, od,nd)).to eq true
      end

      it 'should return true if planned handover date changed in the order' do
        nd = make_data('new-data')
        od = make_data('old-data')
        expect(od).to receive(:planned_handover_date).and_return "2017-01-03"
        expect(nd).to receive(:planned_handover_date).and_return "2017-01-03"
        order.find_and_set_custom_value handover_cdef, Date.new(2017, 1, 4)
        expect(order_data_klass.send_sap_update?(order, od,nd)).to eq true
      end
      
    end

    describe '#lines_needing_pc_approval_reset' do
      it 'should return lines in both hashes with different key values' do
        old_fingerprint = base_fingerprint_hash.deep_dup
        old_fingerprint['lines']['3'] = {ordln_ppu: "100"}
        old_data = order_data_klass.new(old_fingerprint)
        old_data.ship_from_address = 'abc'
        old_data.variant_map = {1=>'10',2=>'11'}
        new_fingerprint = base_fingerprint_hash.deep_dup
        new_fingerprint['lines']['2'] = {ordln_ppu: "1000"}
        new_fingerprint['lines']['4'] = {ordln_ppu: "90"}
        new_data = order_data_klass.new(new_fingerprint)
        new_data.ship_from_address = old_data.ship_from_address
        new_data.variant_map = old_data.variant_map
        # don't return line 1 because it stayed the same
        # don't return line 3 because it was deleted
        # don't return line 4 because it was added
        expect(order_data_klass.lines_needing_pc_approval_reset(old_data,new_data)).to eq ['2']
      end
      it 'should return all lines in new fingerprint if ship from address changed' do
        old_fingerprint = base_fingerprint_hash.deep_dup
        old_data = order_data_klass.new(old_fingerprint)
        old_data.ship_from_address = 'abc'
        old_data.variant_map = {1=>'10',2=>'11'}
        new_fingerprint = base_fingerprint_hash.deep_dup
        new_fingerprint['lines']['4'] = {ordln_ppu: "90"}
        new_data = order_data_klass.new(new_fingerprint)
        new_data.ship_from_address = 'other'
        new_data.variant_map = old_data.variant_map
        expect(order_data_klass.lines_needing_pc_approval_reset(old_data,new_data)).to eq ['1','2','4']
      end
      it 'should not return lines where the only change to the ship from address is whitespace' do
        old_fingerprint = base_fingerprint_hash.deep_dup
        old_data = order_data_klass.new(old_fingerprint)
        old_data.ship_from_address = 'abcdef'
        old_data.variant_map = {1=>'10',2=>'11'}
        new_fingerprint = base_fingerprint_hash.deep_dup
        new_data = order_data_klass.new(new_fingerprint)
        new_data.ship_from_address = " ab c\nde\r\nf"
        new_data.variant_map = old_data.variant_map.clone
        expect(order_data_klass.lines_needing_pc_approval_reset(old_data,new_data)).to eq []
      end
      it 'should return lines with different variants' do
        old_fingerprint = base_fingerprint_hash.deep_dup
        old_data = order_data_klass.new(old_fingerprint)
        old_data.ship_from_address = 'abc'
        old_data.variant_map = {'1'=>'10','2'=>'11'}
        new_fingerprint = base_fingerprint_hash.deep_dup
        new_data = order_data_klass.new(new_fingerprint)
        new_data.ship_from_address = old_data.ship_from_address
        new_data.variant_map = {'1'=>'OTHER','2'=>'11','3'=>'NEW'}
        expect(order_data_klass.lines_needing_pc_approval_reset(old_data,new_data)).to eq ['1','3']
      end
      it "does not reset pc approval if Custom Article Description or Freight Amount changes" do
        old_fingerprint = base_fingerprint_hash.deep_dup
        old_data = order_data_klass.new(old_fingerprint)
        old_data.ship_from_address = 'abc'
        old_data.variant_map = {1=>'10',2=>'11'}
        
        new_fingerprint = base_fingerprint_hash.deep_dup
        new_fingerprint['lines']['1'][cdefs[:ordln_custom_article_description].model_field_uid] = "Changed"
        new_fingerprint['lines']['2'][cdefs[:ordln_vendor_inland_freight_amount].model_field_uid] = "987.65"
        new_data = order_data_klass.new(new_fingerprint)
        new_data.ship_from_address = " abc"
        new_data.variant_map = {1=>'10',2=>'11'}

        expect(order_data_klass.lines_needing_pc_approval_reset(old_data,new_data)).to eq []
      end
    end

    describe '#vendor_visible_fields_changed?' do

      let (:nd) { instance_double(described_class::OrderData) }
      let (:od) { instance_double(described_class::OrderData) }

      it 'should return true if fingerprints are different' do
        [od, nd].each_with_index {|d,i| allow(d).to receive(:fingerprint).and_return(i.to_s); allow(d).to receive(:ship_from_address).and_return('sf')}
        expect(order_data_klass.vendor_visible_fields_changed?(od, nd)).to be_truthy
      end
      it 'should return true if ship from addresses are different' do
        [od, nd].each_with_index {|d,i| allow(d).to receive(:fingerprint).and_return('x'); allow(d).to receive(:ship_from_address).and_return(i.to_s)}
        expect(order_data_klass.vendor_visible_fields_changed?(od, nd)).to be_truthy
      end
      it 'should return true if old_data is nil' do
        expect(order_data_klass.vendor_visible_fields_changed?(nil,nd)).to be_truthy
      end
      it 'should return false if fingerprints are the same and the ship from addresss are the same' do
        [od, nd].each {|d,i| allow(d).to receive(:fingerprint).and_return('x'); allow(d).to receive(:ship_from_address).and_return('sf')}
        expect(order_data_klass.vendor_visible_fields_changed?(od, nd)).to be_falsey
      end
    end
  end

  describe "all_logic_steps" do
    it "returns all logic steps to use" do
      expect(subject.all_logic_steps).to eq [:set_defaults, :planned_handover, :forecasted_handover, :vendor_approvals, :compliance_approvals, :autoflow_approvals,
                    :price_revised_dates, :reset_po_cancellation, :update_change_log, :generate_ll_xml]
    end

    it "excludes approval steps if approval resets are disabled" do
      expect(subject).to receive(:disable_approval_resets?).and_return true
      expect(subject.all_logic_steps).to eq [:set_defaults, :planned_handover, :forecasted_handover, :autoflow_approvals,
                    :price_revised_dates, :reset_po_cancellation, :update_change_log, :generate_ll_xml]
    end
  end

  describe "disable_approval_resets?" do
    it "reads vfitrack configuration and returns false if missing" do
      expect(subject.disable_approval_resets?).to eq false
    end

    it "returns true if configuration has resets disabled" do
      expect(MasterSetup).to receive(:config_true?).with(:disable_lumber_approval_resets).and_return true
      expect(subject.disable_approval_resets?).to eq true
    end
  end

end

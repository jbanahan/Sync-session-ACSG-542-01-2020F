require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator do
  describe '#compare' do
    it 'should do nothing if not an Order type' do
      described_class.should_not_receive(:run_changes)
      described_class.compare 'Product', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
    it 'should build OrderData objects and execute_business_logic' do
      old_data = double('old_order_data')
      new_data = double('new_order_data')
      described_class.should_receive(:build_order_data).with('ob','op','ov').and_return old_data
      described_class.should_receive(:build_order_data).with('nb','np','nv').and_return new_data
      described_class.should_receive(:execute_business_logic).with(1,old_data,new_data)
      described_class.compare 'Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end


    # context 'no auto flow' do
    #   before :each do
    #     described_class.stub(:set_defaults)
    #     described_class.should_receive(:get_fingerprint).with('nb','np','nv').and_return 'newfp'
    #     OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover.stub(:process)
    #   end
    #   it 'should call run_changes if no old version' do
    #     described_class.should_receive(:run_changes)
    #     described_class.compare 'Order', 1, nil, nil, nil, 'nb', 'np', 'nv'
    #   end
    #   it 'should call set defaults' do
    #     ord = double('order')
    #     Order.should_receive(:find_by_id).with(1).and_return ord
    #     described_class.stub(:run_changes)
    #     described_class.should_receive(:set_defaults).with(ord,'newfp')
    #     described_class.compare 'Order', 1, nil, nil, nil, 'nb', 'np', 'nv'
    #   end
    #   it 'should get fingerprints for both versions and call run_changes if they are different' do
    #     described_class.should_receive(:get_fingerprint).with('ob','op','ov').and_return 'oldfp'
    #
    #     described_class.should_receive(:run_changes).with('Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv')
    #     described_class.should_receive(:compare_lines)
    #     described_class.compare 'Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    #   end
    #   it 'should not call run_changes if both versions have the same fingerprint' do
    #     old_h = {'a'=>'b'}
    #     described_class.should_receive(:get_json_hash).with('ob','op','ov').and_return old_h
    #     described_class.should_receive(:fingerprint).with(old_h).and_return 'newfp'
    #
    #     described_class.should_not_receive(:run_changes)
    #     described_class.compare 'Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    #   end
    # end
    # context "auto flow" do
    #   before :each do
    #     described_class.stub(:set_defaults)
    #     @ord = double('order')
    #     Order.should_receive(:find_by_id).with(1).and_return @ord
    #     OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover.should_receive(:process).with(@ord)
    #   end
    #   it "should run AutoFlow if there are changes" do
    #     old_h = {'a'=>'b'}
    #     new_h = {'c'=>'d'}
    #     described_class.should_receive(:get_json_hash).with('ob','op','ov').and_return old_h
    #     described_class.should_receive(:get_json_hash).with('nb','np','nv').and_return new_h
    #     described_class.should_receive(:fingerprint).with(old_h).and_return 'oldfp'
    #     described_class.should_receive(:fingerprint).with(new_h).and_return 'newfp'
    #
    #     described_class.should_receive(:run_changes).with('Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv')
    #     described_class.should_receive(:compare_lines)
    #     described_class.compare 'Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    #   end
    #   it "should run AutoFlow even if no fingerprint changes" do
    #     old_h = {'a'=>'b'}
    #     new_h = {'c'=>'d'}
    #     described_class.should_receive(:get_json_hash).with('ob','op','ov').and_return old_h
    #     described_class.should_receive(:get_json_hash).with('nb','np','nv').and_return new_h
    #     described_class.should_receive(:fingerprint).with(old_h).and_return 'fp'
    #     described_class.should_receive(:fingerprint).with(new_h).and_return 'fp'
    #
    #     described_class.should_not_receive(:run_changes)
    #     described_class.compare 'Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    #   end
    # end
  end

  describe 'build_order_data' do
    it 'should return nil if bucket is nil' do
      expect(described_class.build_order_data(nil, nil, nil)).to be_nil
    end
    it 'should return from JSON hash if bucket is not nil' do
      h = double('hash')
      od = double('OrderData')
      described_class.should_receive(:get_json_hash).with('a','b','c').and_return h
      described_class::OrderData.should_receive(:build_from_hash).with(h).and_return od
      expect(described_class.build_order_data('a','b','c')).to eq od
    end
  end

  describe '#execute_business_logic' do
    before :each do
      @order_id = 1
      @o = double('order')
      @o.stub(:reload)
      @old_data = double('od')
      @new_data = double('nd')
      Order.stub(:find_by_id).and_return @o

      # stub all business logic methods, then in each test we use should_receive for the one we're testing
      described_class.stub(:set_defaults).and_return false
      described_class.stub(:update_autoflow_approvals).and_return false
      described_class.stub(:reset_vendor_approvals).and_return false
      described_class.stub(:reset_product_compliance_approvals).and_return false
      described_class.stub(:create_pdf).and_return false
    end
    it 'should return if order does not exist' do
      Order.stub(:find_by_id).and_return nil
      described_class.should_not_receive(:set_defaults)
      expect(described_class.execute_business_logic(1,@old_data,@new_data)).to be_false
    end
    it 'should set defaults' do
      described_class.should_receive(:set_defaults).with(@o,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should reset vendor approvals' do
      described_class.should_receive(:reset_vendor_approvals).with(@o,@old_data,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should reset PC / Exec PC approvals' do
      described_class.should_receive(:reset_product_compliance_approvals).with(@o,@old_data,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should autoflow' do
      described_class.should_receive(:update_autoflow_approvals).with(@o)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should generate new PDF' do
      described_class.stub(:set_defaults).and_return false
      described_class.should_receive(:create_pdf).with(@o,@old_data,@new_data)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
    it 'should not generate new PDF if default values were updated' do
      described_class.stub(:set_defaults).and_return true
      described_class.should_not_receive(:create_pdf)
      described_class.execute_business_logic(1,@old_data,@new_data)
    end
  end

  describe '#set_defaults' do
    before :each do
      @k = OpenChain::CustomHandler::LumberLiquidators::LumberOrderDefaultValueSetter
    end
    it 'should call if order_data#has_blank_defaults?' do
      o = double('order')
      d = double('OrderData')
      d.should_receive(:has_blank_defaults?).and_return true
      @k.should_receive(:set_defaults).with(o).and_return true
      expect(described_class.set_defaults(o,d)).to be_true
    end
    it 'should return false if has_blank_defaults? but nothing is changed' do
      o = double('order')
      d = double('OrderData')
      d.should_receive(:has_blank_defaults?).and_return true
      @k.should_receive(:set_defaults).with(o).and_return false
      expect(described_class.set_defaults(o,d)).to be_false
    end
    it 'should not call if !order_data#has_blank_defaults?' do
      o = double('order')
      d = double('OrderData')
      d.should_receive(:has_blank_defaults?).and_return false
      @k.should_not_receive(:set_defaults)
      expect(described_class.set_defaults(o,d)).to be_false
    end

  end

  describe '#update_autoflow_approvals' do
    it 'should call AutoFlowApprover' do
      o = double('order')
      OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover.should_receive(:process).with(o).and_return true
      expect(described_class.update_autoflow_approvals(o)).to be_true
    end
    it 'should return value of AutoFlowApprover' do
      o = double('order')
      OpenChain::CustomHandler::LumberLiquidators::LumberAutoflowOrderApprover.should_receive(:process).with(o).and_return false
      expect(described_class.update_autoflow_approvals(o)).to be_false
    end
  end

  describe '#reset_vendor_approvals' do
    before :each do
      @nd = double('newdata')
      @od = double('olddata')
      @o = double(:order)
      @u = double(:user)
      User.stub(:integration).and_return @u
    end
    it 'should reset if OrderData#vendor_approval_reset_fields_changed? and order is accepted' do
      described_class::OrderData.should_receive(:vendor_approval_reset_fields_changed?).with(@od,@nd).and_return true
      @o.should_receive(:approval_status).and_return 'Accepted'
      @o.should_receive(:unaccept!).with(@u)
      expect(described_class.reset_vendor_approvals(@o,@od,@nd)).to be_true
    end
    it 'should not reset if !OrderData#vendor_approval_reset_fields_changed?' do
      described_class::OrderData.should_receive(:vendor_approval_reset_fields_changed?).with(@od,@nd).and_return false
      @o.should_not_receive(:unaccept!)
      expect(described_class.reset_vendor_approvals(@o,@od,@nd)).to be_false
    end
    it 'should not reset if OrderData#vendor_approval_reset_fields_changed? && order not accepted' do
      described_class::OrderData.should_receive(:vendor_approval_reset_fields_changed?).with(@od,@nd).and_return true
      @o.should_receive(:approval_status).and_return ''
      @o.should_not_receive(:unaccept!)
      expect(described_class.reset_vendor_approvals(@o,@od,@nd)).to be_false
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
      User.stub(:integration).and_return(@integration)
      @cdefs = described_class.prep_custom_definitions([:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive])
    end
    it 'should reset lines that changed' do
      lines = [@ol1,@ol2]
      [:ordln_pc_approved_by,:ordln_pc_approved_by_executive].each do |uid|
        lines.each {|ln| ln.update_custom_value!(@cdefs[uid],@u.id)}
      end
      [:ordln_pc_approved_date,:ordln_pc_approved_date_executive].each do |uid|
        lines.each {|ln| ln.update_custom_value!(@cdefs[uid],Time.now)}
      end

      described_class::OrderData.should_receive(:lines_needing_pc_approval_reset).with(@od,@nd).and_return ['1']
      @ord.should_receive(:create_snapshot).with(@integration)

      expect(described_class.reset_product_compliance_approvals(@ord,@od,@nd)).to be_true

      @ol1.reload
      @ol2.reload
      @cdefs.values.each do |cd|
        expect(@ol1.get_custom_value(cd).value).to be_blank
        expect(@ol2.get_custom_value(cd).value).to_not be_blank
      end

    end
    it 'should return false if lines changed but they were not approved' do
      described_class::OrderData.should_receive(:lines_needing_pc_approval_reset).with(@od,@nd).and_return ['1']
      @ord.should_not_receive(:create_snapshot)

      expect(described_class.reset_product_compliance_approvals(@ord,@od,@nd)).to be_false

    end
    it 'should return false if no lines changed' do
      [:ordln_pc_approved_by,:ordln_pc_approved_by_executive].each do |uid|
        @ol1.update_custom_value!(@cdefs[uid],@u.id)
      end
      [:ordln_pc_approved_date,:ordln_pc_approved_date_executive].each do |uid|
        @ol1.update_custom_value!(@cdefs[uid],Time.now)
      end

      described_class::OrderData.should_receive(:lines_needing_pc_approval_reset).with(@od,@nd).and_return []
      @ord.should_not_receive(:create_snapshot)

      expect(described_class.reset_product_compliance_approvals(@ord,@od,@nd)).to be_false

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
      User.stub(:integration).and_return(@integration)
      @k = OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator
    end
    it 'should create pdf if OrderData#needs_new_pdf?' do
      described_class::OrderData.should_receive(:needs_new_pdf?).with(@od,@nd).and_return true
      @k.should_receive(:create!).with(@o,@integration)
      expect(described_class.create_pdf(@o,@od,@nd)).to be_true
    end
    it 'should not create pdf if !OrderData#needs_new_pdf?' do
      described_class::OrderData.should_receive(:needs_new_pdf?).with(@od,@nd).and_return false
      @k.should_not_receive(:create!)
      expect(described_class.create_pdf(@o,@od,@nd)).to be_false
    end
  end

  describe 'OrderData' do
    describe '#build_from_hash' do
      before :each do
        @cdefs = described_class.prep_custom_definitions([:ord_country_of_origin])
        # constant is loaded with custom definition model field IDs which change
        # each run in test because the CustomDefinitions are regenerated, so we
        # manually clear it. No need to do this in dev/production.
        described_class::OrderData::ORDER_CUSTOM_FIELDS.clear
      end
      it 'should create order data from hash' do
        p = Factory(:product,unique_identifier:'px')
        ol = Factory(:order_line,line_number:1,product:p,quantity:10,unit_of_measure:'EA',price_per_unit:5)
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
        o.reload

        expected_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN~~1~px~10.0~EA~5.0~~2~px~50.0~FT~7.0"

        h = JSON.parse(CoreModule::ORDER.entity_json(o))

        od = described_class::OrderData.build_from_hash(h)
        expect(od.fingerprint).to eq expected_fingerprint
      end
    end

    describe '#has_blank_defaults?' do
      it 'should be false if none of the fields defaulted from the vendor are blank' do
        fp = 'ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN'
        expect(described_class::OrderData.new(fp).has_blank_defaults?).to be_false
      end
      it 'should be true if ship terms are blank' do
        fp = 'ON1~2015-01-01~2015-01-10~USD~NT30~~Shanghai~CN'
        expect(described_class::OrderData.new(fp).has_blank_defaults?).to be_true
      end
      it 'should be true if fob point is blank' do
        fp = 'ON1~2015-01-01~2015-01-10~USD~NT30~FOB~~CN'
        expect(described_class::OrderData.new(fp).has_blank_defaults?).to be_true
      end
      it 'should be true if country of origin is blank' do
        fp = 'ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~'
        expect(described_class::OrderData.new(fp).has_blank_defaults?).to be_true
      end
    end

    describe '#vendor_approval_reset_fields_changed?' do
      it 'should return true if fingerprints are different' do
        od = double(:od)
        nd = double(:nd)
        [od,nd].each_with_index {|d,i| d.stub(:fingerprint).and_return(i.to_s)}
        expect(described_class::OrderData.vendor_approval_reset_fields_changed?(od,nd)).to be_true
      end
      it 'should return false if fingerprints are the same' do
        od = double(:od)
        nd = double(:nd)
        [od,nd].each {|d| d.stub(:fingerprint).and_return('x')}
        expect(described_class::OrderData.vendor_approval_reset_fields_changed?(od,nd)).to be_false
      end
      it 'should return false if old_data is nil' do
        nd = double(:nd)
        expect(described_class::OrderData.vendor_approval_reset_fields_changed?(nil,nd)).to be_false
      end
    end

    describe '#lines_needing_pc_approval_reset' do
      it 'should return lines in both hashes with different key values' do
        old_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN~~1~px~10.0~EA~5.0~~2~px~50.0~FT~7.0~~3~px~50.0~FT~7.0"
        old_data = described_class::OrderData.new(old_fingerprint)
        new_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~Shanghai~CN~~1~px~10.0~EA~5.0~~2~px~22.0~FT~7.0~~4~px~50.0~FT~7.0"
        new_data = described_class::OrderData.new(new_fingerprint)
        # don't return line 1 because it stayed the same
        # don't return line 3 because it was deleted
        # don't return line 4 because it was added
        expect(described_class::OrderData.lines_needing_pc_approval_reset(old_data,new_data)).to eq ['2']
      end
    end

    describe '#needs_new_pdf?' do
      before :each do
        @od = double('old_data')
        @nd = double('new_data')
      end
      it 'should return true if fingerprints are different' do
        [@od,@nd].each_with_index {|d,i| d.stub(:fingerprint).and_return(i.to_s)}
        expect(described_class::OrderData.needs_new_pdf?(@od,@nd)).to be_true
      end
      it 'should return true if old_data is nil' do
        expect(described_class::OrderData.needs_new_pdf?(nil,@nd)).to be_true
      end
      it 'should return false if fingerprints are the same' do
        [@od,@nd].each {|d,i| d.stub(:fingerprint).and_return('x')}
        expect(described_class::OrderData.needs_new_pdf?(@od,@nd)).to be_false
      end
    end
  end

end

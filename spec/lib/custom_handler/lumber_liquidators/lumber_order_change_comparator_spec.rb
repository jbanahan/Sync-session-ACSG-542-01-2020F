require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderChangeComparator do
  describe '#compare' do
    it 'should do nothing if not an Order type' do
      described_class.should_not_receive(:run_changes)
      described_class.compare 'Product', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
    it 'should call run_changes if no old version' do
      described_class.should_receive(:run_changes)
      described_class.compare 'Order', 1, nil, nil, nil, 'nb', 'np', 'nv'
    end
    it 'should get fingerprints for both versions and call run_changes if they are different' do
      old_h = {'a'=>'b'}
      new_h = {'c'=>'d'}
      described_class.should_receive(:get_json_hash).with('ob','op','ov').and_return old_h
      described_class.should_receive(:get_json_hash).with('nb','np','nv').and_return new_h
      described_class.should_receive(:fingerprint).with(old_h).and_return 'oldfp'
      described_class.should_receive(:fingerprint).with(new_h).and_return 'newfp'

      described_class.should_receive(:run_changes).with('Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv')
      described_class.should_receive(:compare_lines)
      described_class.compare 'Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
    it 'should not call run_changes if both versions have the same fingerprint' do
      old_h = {'a'=>'b'}
      new_h = {'c'=>'d'}
      described_class.should_receive(:get_json_hash).with('ob','op','ov').and_return old_h
      described_class.should_receive(:get_json_hash).with('nb','np','nv').and_return new_h
      described_class.should_receive(:fingerprint).with(old_h).and_return 'fp'
      described_class.should_receive(:fingerprint).with(new_h).and_return 'fp'

      described_class.should_not_receive(:run_changes)
      described_class.compare 'Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
  end
  describe '#fingerprint' do
    it 'should generate from JSON hash' do
      p = Factory(:product,unique_identifier:'px')
      ol = Factory(:order_line,line_number:1,product:p,quantity:10,unit_of_measure:'EA',price_per_unit:5)
      Factory(:order_line,order:ol.order,line_number:2,product:p,quantity:50,unit_of_measure:'FT',price_per_unit:7)
      o = ol.order
      o.update_attributes(order_number:'ON1',ship_window_start:Date.new(2015,1,1),ship_window_end:Date.new(2015,1,10),currency:'USD',terms_of_payment:'NT30',terms_of_sale:'FOB')
      o.reload

      expected_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB~~1~px~10.0~EA~5.0~~2~px~50.0~FT~7.0"

      h = JSON.parse(CoreModule::ORDER.entity_json(o))

      expect(described_class.fingerprint(h)).to eq expected_fingerprint
    end
    it "should generate if no order lines" do
      o = Factory(:order,order_number:'ON1',ship_window_start:Date.new(2015,1,1),ship_window_end:Date.new(2015,1,10),currency:'USD',terms_of_payment:'NT30',terms_of_sale:'FOB')
      expected_fingerprint = "ON1~2015-01-01~2015-01-10~USD~NT30~FOB"
      h = JSON.parse(CoreModule::ORDER.entity_json(o))

      expect(described_class.fingerprint(h)).to eq expected_fingerprint
    end
  end
  describe '#get_json_hash' do
    it 'should get JSON hash from s3 data' do
      h = {'a'=>'b'}
      json = h.to_json
      OpenChain::S3.should_receive(:get_versioned_data).with('b','k','v').and_return json
      expect(described_class.get_json_hash('b','k','v')).to eq h
    end
  end
  describe '#run_changes' do
    before :each do
      @u = double('user')
      @o = double('order')
      Order.should_receive(:find).with(1).and_return @o
      User.stub(:integration).and_return @u
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator.stub(:create!)
      @o.stub(:unaccept!)
    end
    it 'should call Order PDF generator' do
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator.should_receive(:create!).with(@o, User.integration)
      @o.should_receive(:approval_status).and_return nil
      described_class.run_changes 'Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
    it "should clear approval" do
      @o.should_receive(:unaccept!).with(@u)
      @o.should_receive(:approval_status).and_return 'Approved'
      described_class.run_changes 'Order', 1, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
  end

  describe '#compare_lines' do
    it "should only run lines changes for lines that changed" do
      fingerprint_1 = 'ON1~2015-01-01~2015-01-10~USD~NT30~FOB~~1~px~10.0~EA~5.0~~2~px~50.0~FT~7.0~~3~ab~19.2~FT~8.4'
      fingerprint_2 = 'ON1~2015-01-01~2015-01-10~USD~NT30~FOB~~1~px~10.1~EA~5.0~~2~px~50.0~FT~7.0'
      order_id = 10
      described_class.should_receive(:run_line_changes).with(10,'1',instance_of(Hash))
      described_class.should_receive(:run_line_changes).with(10,'3',instance_of(Hash))
      described_class.compare_lines(order_id,fingerprint_1,fingerprint_2)
    end
  end
  describe '#run_line_changes' do
    it "should unapprove for both PC & Exec PC" do
      cdefs = described_class.prep_custom_definitions([:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive])
      u = Factory(:user)
      ol = Factory(:order_line,line_number:3)
      ol.update_custom_value!(cdefs[:ordln_pc_approved_by],u.id)
      ol.update_custom_value!(cdefs[:ordln_pc_approved_date],Time.now)
      ol.update_custom_value!(cdefs[:ordln_pc_approved_by_executive],u.id)
      ol.update_custom_value!(cdefs[:ordln_pc_approved_date_executive],Time.now)

      described_class.run_line_changes(ol.order_id,'3')

      ol.reload
      [:ordln_pc_approved_by,:ordln_pc_approved_date,:ordln_pc_approved_by_executive,:ordln_pc_approved_date_executive].each do |uid|
        expect(ol.get_custom_value(cdefs[uid]).value).to be_blank
      end
    end
  end
end

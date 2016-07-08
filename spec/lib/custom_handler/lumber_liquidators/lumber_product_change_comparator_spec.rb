require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberProductChangeComparator do
  describe '#accept?' do
    it 'should accept products' do
      expect(described_class.accept?(EntitySnapshot.new(recordable_type:'Product'))).to be_true
    end
    it 'should not accept non-products' do
      expect(described_class.accept?(EntitySnapshot.new(recordable_type:'Order'))).to be_false
    end
  end
  describe '#compare' do
    it 'should try to update merch description' do
      old_hash = double('oh')
      old_data = double('od')
      new_hash = double('nh')
      new_data = double('nd')
      cdefs = double('cdefs')
      # make sure the method we're stubbing actually exists since it's implemented
      # in ComparatorHelper and isn't unit tested in this spec
      expect(described_class.methods.include?(:get_json_hash)).to be_true
      described_class.should_receive(:my_custom_definitions).and_return cdefs
      described_class.should_receive(:get_json_hash).with('ob','op','ov').and_return old_hash
      described_class.should_receive(:get_json_hash).with('nb','np','nv').and_return new_hash
      described_class.should_receive(:build_data).with(old_hash,cdefs).and_return old_data
      described_class.should_receive(:build_data).with(new_hash,cdefs).and_return new_data
      described_class.should_receive(:process_merch_cat_description).with(1,old_data,new_data,cdefs)
      described_class.compare('Product',1,'ob','op','ov','nb','np','nv')
    end
  end

  describe '#build_data' do
    it 'should build data object' do
      cdefs = described_class.my_custom_definitions
      data = {"entity"=>{"model_fields"=>{cdefs[:prod_merch_cat].model_field_uid.to_s=>"MC",cdefs[:prod_merch_cat_desc].model_field_uid.to_s=>"MCD"}}}
      obj = described_class.build_data(data,cdefs)
      expect(obj.merch_cat).to eq 'MC'
      expect(obj.merch_cat_desc).to eq 'MCD'
    end
  end
  describe '#process_merch_cat_description' do
    let :cdefs do
      double(:custom_defs)
    end
    it 'should do nothing if description did not change' do
      described_class.should_not_receive(:update_merch_cat_description)
      old_data = double(:old_data)
      new_data = double(:new_data)
      [old_data,new_data].each {|d| d.stub(:merch_cat_desc).and_return 'MC'}
      described_class.process_merch_cat_description(1,old_data,new_data,cdefs)
    end
    it 'should do nothing if new data does not have merch_cat_desc' do
      new_data = double(:new_data)
      new_data.stub(:merch_cat_desc).and_return nil
      described_class.should_not_receive(:update_merch_cat_description)
      described_class.process_merch_cat_description(1,nil,new_data,cdefs)
    end
    it 'should call update if new product' do
      new_data = double(:new_data)
      new_data.stub(:merch_cat_desc).and_return 'MC'
      described_class.should_receive(:update_merch_cat_description).with(1,new_data,cdefs)
      described_class.process_merch_cat_description(1,nil,new_data,cdefs)
    end
    it 'should call update if description changed' do
      old_data = double(:old_data)
      new_data = double(:new_data)
      [old_data,new_data].each_with_index {|d,i| d.stub(:merch_cat_desc).and_return "MC#{i}"}
      described_class.should_receive(:update_merch_cat_description).with(1,new_data,cdefs)
      described_class.process_merch_cat_description(1,old_data,new_data,cdefs)
    end
  end
  describe '#update_merch_cat_description' do
    it 'should update merch description on products with different description and same category' do
      cdefs = described_class.my_custom_definitions
      base_p = Factory(:product)
      other_p = Factory(:product)
      [base_p,other_p].each_with_index do |p,i|
        p.update_custom_value!(cdefs[:prod_merch_cat],'123')
        p.update_custom_value!(cdefs[:prod_merch_cat_desc],"MCD#{i}")
      end
      new_data = double('new_data')
      new_data.stub(:merch_cat).and_return '123'
      new_data.stub(:merch_cat_desc).and_return 'MCD0'
      expect{described_class.update_merch_cat_description base_p.id, new_data, cdefs}.to change(EntitySnapshot,:count).from(0).to(1)
      other_p.reload
      expect(other_p.get_custom_value(cdefs[:prod_merch_cat_desc]).value).to eq 'MCD0'
      expect(other_p.entity_snapshots).to_not be_blank
    end
    it 'should do nothing if other products have same description' do
      cdefs = described_class.my_custom_definitions
      base_p = Factory(:product)
      other_p = Factory(:product)
      [base_p,other_p].each do |p|
        p.update_custom_value!(cdefs[:prod_merch_cat],'123')
        p.update_custom_value!(cdefs[:prod_merch_cat_desc],"MCD0")
      end
      new_data = double('new_data')
      new_data.stub(:merch_cat).and_return '123'
      new_data.stub(:merch_cat_desc).and_return 'MCD0'
      expect{described_class.update_merch_cat_description base_p.id, new_data, cdefs}.to_not change(EntitySnapshot,:count)
    end
  end
end

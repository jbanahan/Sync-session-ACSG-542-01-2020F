require 'spec_helper'

describe CustomViewTemplate do
  describe '#for_object' do
    before :each do
      @cvt = CustomViewTemplate.create!(template_identifier:'sample',template_path:'/x')
      @cvt.search_criterions.create!(model_field_uid:'ord_ord_num',operator:'eq',value:'ABC')
    end
    it 'should return nil for no template identifier match' do
      o = Order.new(order_number:'ABC')
      expect(CustomViewTemplate.for_object('other',o)).to be_nil
    end
    it 'should return nil for no search criterion match' do
      o = Order.new(order_number:'BAD')
      expect(CustomViewTemplate.for_object('sample',o)).to be_nil
    end
    it 'should return template for match' do
      o = Order.new(order_number:'ABC')
      expect(CustomViewTemplate.for_object('sample',o)).to eq '/x'
    end
    it "should return default for no match" do
      expect(CustomViewTemplate.for_object('other',Order.new,'/y')).to eq '/y'
    end
  end
end

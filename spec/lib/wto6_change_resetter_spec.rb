require 'spec_helper'

describe OpenChain::Wto6ChangeResetter do
  describe "reset_fields_if_changed" do
    before(:each) do
      @cr = 50.days.ago
      @p = Factory(:product,name:'myname',created_at:@cr)
      @flds = ['prod_name']
    end
    it "should reset fields if changed" do
      @p.should_receive(:wto6_changed_after?).with(@cr).and_return(true)
      described_class.reset_fields_if_changed(@p,'prod_created_at',['prod_name'])
      @p.reload
      expect(@p.name).to be_blank
    end
    it "should not reset fields if not changed" do
      @p.should_receive(:wto6_changed_after?).with(@cr).and_return(false)
      described_class.reset_fields_if_changed(@p,'prod_created_at',['prod_name'])
      @p.reload
      expect(@p.name).to eq 'myname'
    end
  end
  describe "run_schedulable" do
    it "should get products based on last_started_at" do
      cr = 12.days.ago
      p = Factory(:product,updated_at:6.days.ago,created_at:cr)
      p2 = Factory(:product,updated_at:4.days.ago,created_at:cr)
      d = 5.days.ago
      described_class.should_receive(:reset_fields_if_changed).with(p2,'prod_created_at',['prod_name'])
      described_class.run_schedulable({'last_started_at'=>d,'change_date_field'=>'prod_created_at','fields_to_reset'=>['prod_name']})
    end
  end
end
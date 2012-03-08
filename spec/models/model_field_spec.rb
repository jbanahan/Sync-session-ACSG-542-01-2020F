require 'spec_helper'

describe ModelField do
  describe "can_view?" do
    it "should default to true" do
      ModelField.new(1,:x,CoreModule::SHIPMENT,:z).can_view?(Factory(:user)).should be_true
    end
    it "should be false when lambda returns false" do
      ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:can_view_lambda=>lambda {|user| false}}).can_view?(Factory(:user)).should be_false
    end
    context "process_export" do
      it "should return HIDDEN for process_export if can_view? is false" do
        ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:export_lambda=>lambda {|obj| "a"},:can_view_lambda=>lambda {|u| false}}).process_export("x",Factory(:user)).should == "HIDDEN"
      end
      it "should return appropriate value for process_export if can_view? is true" do
        ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:export_lambda=>lambda {|obj| "a"},:can_view_lambda=>lambda {|u| true}}).process_export("x",Factory(:user)).should == "a"
      end
      it "should skip check if always_view is true" do
        ModelField.new(1,:x,CoreModule::SHIPMENT,:z,{:export_lambda=>lambda {|obj| "a"},:can_view_lambda=>lambda {|u| false}}).process_export("x",Factory(:user),true).should == "a"
      end
    end
  end
  context "special cases" do
    context "broker_invoice_total" do
      before :each do
        MasterSetup.get.update_attributes(:broker_invoice_enabled=>true)
      end
      it "should allow you to see broker_invoice_total if you can view broker_invoices" do
        u = Factory(:user,:broker_invoice_view=>true,:company=>Factory(:company,:master=>true))
        ModelField.find_by_uid(:ent_broker_invoice_total).can_view?(u).should be_true
      end
      it "should not allow you to see broker_invoice_total if you can't view broker_invoices" do
        u = Factory(:user,:broker_invoice_view=>false)
        ModelField.find_by_uid(:ent_broker_invoice_total).can_view?(u).should be_false
      end
    end
    context "product last_changed_by" do
      it "should apply search criterion properly" do
        c = Factory(:company,:master=>true)
        p = Factory(:product)
        p2 = Factory(:product)
        u1 = Factory(:user,:username=>'abcdef',:company=>c)
        u2 = Factory(:user,:username=>'ghijkl',:company=>c)
        p.create_snapshot u1
        p.create_snapshot u2
        p2.create_snapshot u1
        ss = Factory(:search_setup,:module_type=>'Product',:user=>u1)
        ss.search_criterions.create!(:model_field_uid=>'prod_last_changed_by',
          :operator=>'sw',:value=>'ghi')
        found = ss.search.to_a
        found.should have(1).product
        found.first.should == p
      end
    end
  end
end

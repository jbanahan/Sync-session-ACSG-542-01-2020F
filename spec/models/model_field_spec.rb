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
    context "first HTS code" do
      before :each do
        country_1 = Factory(:country,:classification_rank=>1)
        country_2 = Factory(:country,:classification_rank=>2)
        @p = Factory(:product)
        class_1 = @p.classifications.create!(:country_id=>country_1.id)
        class_2 = @p.classifications.create!(:country_id=>country_2.id)
        t_1 = class_1.tariff_records.create!(:hts_1=>'1234567890')
        t_2 = class_2.tariff_records.create!(:hts_2=>'9999999999')
        @mf = ModelField.find_by_uid :prod_first_hts
      end
      it "process_export should match first hts code for first country" do
        @mf.process_export(@p, nil, true).should == '1234.56.7890'
      end
      it "should match on search criterion" do
        sc = SearchCriterion.new(:model_field_uid=>'prod_first_hts',:operator=>'sw',:value=>'123456')
        r = sc.apply Product.where('1=1')
        r.first.should == @p
      end
    end
    context "hts formatting" do
      it "should handle query parameters for hts formatting" do
        tr = TariffRecord.new(:hts_1=>"1234567890",:hts_2=>"0987654321",:hts_3=>"123456")
        [:hts_hts_1,:hts_hts_2,:hts_hts_3].each do |mfuid|
          mf = ModelField.find_by_uid mfuid
          export = mf.process_export tr, nil, true
          exp_for_qry = mf.process_query_parameter tr
          case mfuid
            when :hts_hts_1
              export.should == "1234.56.7890"
              exp_for_qry.should == "1234567890"
            when :hts_hts_2
              export.should == "0987.65.4321"
              exp_for_qry.should == "0987654321"
            when :hts_hts_3
              export.should == "1234.56"
              exp_for_qry.should == "123456"
            else
              fail "Should have hit one of the tests"
          end
        end
      end
    end
    describe :process_query_parameter do
      p = Product.new(:unique_identifier=>"abc")
      ModelField.find_by_uid(:prod_uid).process_query_parameter(p).should == "abc"
    end

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
    context "broker security" do
      before :each do
        @broker_user = Factory(:user,:company=>Factory(:company,:broker=>true))
        @non_broker_user = Factory(:user)
      end
      it "should allow duty due date if user is broker company" do
        u = @broker_user
        ModelField.find_by_uid(:ent_duty_due_date).can_view?(u).should be_true
        ModelField.find_by_uid(:bi_duty_due_date).can_view?(u).should be_true
      end
      it "should not allow duty due date if user is not a broker" do
        u = @non_broker_user
        ModelField.find_by_uid(:ent_duty_due_date).can_view?(u).should be_false
        ModelField.find_by_uid(:bi_duty_due_date).can_view?(u).should be_false
      end
      it "should secure error_free_release" do
        mf = ModelField.find_by_uid(:ent_error_free_release) 
        mf.can_view?(@broker_user).should be_true
        mf.can_view?(@non_broker_user).should be_false
      end
      it "should secure census warning" do
        mf = ModelField.find_by_uid(:ent_census_warning) 
        mf.can_view?(@broker_user).should be_true
        mf.can_view?(@non_broker_user).should be_false
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

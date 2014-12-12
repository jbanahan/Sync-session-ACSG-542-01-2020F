require 'spec_helper'

describe CoreModule do

  it 'should return class by calling klass' do
    CoreModule::PRODUCT.klass.should be Product
  end
  describe 'top?' do
    it "should return true for top of chain" do
      CoreModule::PRODUCT.default_module_chain.top?(CoreModule::PRODUCT).should be_true
    end
    it "should return false for item with parent in chain" do
      CoreModule::PRODUCT.default_module_chain.top?(CoreModule::CLASSIFICATION).should be_false
    end
    it "should return false for item not in chain" do
      CoreModule::PRODUCT.default_module_chain.top?(CoreModule::SHIPMENT).should be_false
    end
  end
  describe :validate_business_logic do
    it "should validate business logic" do
      p = Product.new
      x = double('my validation')
      x.should_receive(:validation_call).with(p)
      l = lambda {|obj| x.validation_call(obj)}
      cm = CoreModule.new('Product','Product',{business_logic_validations:l})
      cm.validate_business_logic p
    end
    it "should call Product.validate_tariff_numbers" do
      ot = Factory(:official_tariff)
      p = Product.new
      p.classifications.build(country:ot.country).tariff_records.build(hts_1:"#{ot.hts_code}X")
      CoreModule::PRODUCT.validate_business_logic(p).should be_false
      p.errors[:base].first.should == "Tariff number #{ot.hts_code}X is invalid for #{ot.country.iso_code}"
    end
  end
  describe 'key_columns' do
    it 'should return for entry' do
      uids = CoreModule::ENTRY.key_model_field_uids
      uids.should == [:ent_brok_ref]
      uids.first.should be_a_model_field_uid
    end
    it 'should return for order' do
      uids = CoreModule::ORDER.key_model_field_uids
      uids.should == [:ord_ord_num]
      uids.each {|u| u.should be_a_model_field_uid}
    end
    it 'should return for order line' do
      uids = CoreModule::ORDER_LINE.key_model_field_uids
      uids.should == [:ordln_line_number]
      uids.each {|u| u.should be_a_model_field_uid}
    end

    it 'should return for shipment line' do
      uids = CoreModule::SHIPMENT_LINE.key_model_field_uids
      uids.should == [:shpln_line_number]
      uids.each {|u| u.should be_a_model_field_uid}
    end

    it 'should return for shipment' do
      uids = CoreModule::SHIPMENT.key_model_field_uids
      uids.should == [:shp_ref]
      uids.each {|u| u.should be_a_model_field_uid}
    end

    it 'should return for sale line' do
      uids = CoreModule::SALE_LINE.key_model_field_uids
      uids.should == [:soln_line_number]
      uids.each {|u| u.should be_a_model_field_uid}
    end

    it 'should return for sale' do
      uids = CoreModule::SALE.key_model_field_uids
      uids.should == [:sale_order_number]
      uids.each {|u| u.should be_a_model_field_uid}
    end

    it 'should return for delivery line' do
      uids = CoreModule::DELIVERY_LINE.key_model_field_uids
      uids.should == [:delln_line_number]
      uids.each {|u| u.should be_a_model_field_uid}
    end

    it 'should return for delivery' do
      uids = CoreModule::DELIVERY.key_model_field_uids
      uids.should == [:del_ref]
      uids.each {|u| u.should be_a_model_field_uid}
    end

    it 'should return for tariff' do
      uids = CoreModule::TARIFF.key_model_field_uids
      uids.should == [:hts_line_number]
      uids.each {|u| u.should be_a_model_field_uid}
    end

    it 'should return for classification' do
      uids = CoreModule::CLASSIFICATION.key_model_field_uids
      uids.should == [:class_cntry_name,:class_cntry_iso]
      uids.each {|u| u.should be_a_model_field_uid}
    end

    it 'should return for product' do
      uids = CoreModule::PRODUCT.key_model_field_uids
      uids.should == [:prod_uid]
      uids.each {|u| u.should be_a_model_field_uid}
    end

    it 'should return for official tariff' do
      uids = CoreModule::OFFICIAL_TARIFF.key_model_field_uids
      uids.should == []
    end
  end

  describe "model_fields" do
    it "returns all model fields that are user accessible" do
      all_fields = ModelField.find_by_core_module(CoreModule::SALE).select {|m| m.user_accessible?}
      expect(CoreModule::SALE.model_fields.values.size).to eq all_fields.size
    end

    it "uses given block to strip fields" do
      counter = 0
      fields = CoreModule::SALE.model_fields {|mf| (counter+=1) < 2}
      expect(fields.size).to eq 1
    end

    it "removes fields given user can't see" do
      u = User.new
      ModelField.any_instance.stub(:can_view?).with(u).and_return false
      expect(CoreModule::SALE.model_fields(u).size).to eq 0
    end
  end

  describe "model_fields_including_children" do
    it "returns all fields for all levels of module" do
      fields = CoreModule::SECURITY_FILING.model_fields_including_children
      expect(fields.size).to eq CoreModule::SECURITY_FILING.model_fields.size + CoreModule::SECURITY_FILING_LINE.model_fields.size
    end

    it "returns all fields for all levels of module user has access to" do
      u = User.new
      ModelField.any_instance.stub(:can_view?).with(u).and_return false
      expect(CoreModule::SECURITY_FILING.model_fields_including_children(u).size).to eq 0
    end

    it "users given block to strip fields" do
      fields = CoreModule::SECURITY_FILING.model_fields_including_children {|mf| mf.uid.to_s =~ /sfln_/}
      expect(fields.size).to eq CoreModule::SECURITY_FILING_LINE.model_fields.size
    end
  end

  describe "child_association_name" do
    it "returns the name of the association used to join parent module to child" do
      expect(CoreModule::PRODUCT.child_association_name(CoreModule::CLASSIFICATION)).to eq "classifications"
    end

    it "raises an error on an invalid child" do
      expect {CoreModule::PRODUCT.child_association_name(CoreModule::ENTRY)}.to raise_error  ArgumentError, "Failed to find association for #{CoreModule::ENTRY.klass} in #{CoreModule::PRODUCT.klass}."
    end

    it "does not error for children of all core modules" do
      # This just validates that the core module setups are ok
      # The test passes as long as no errors are raised
      CoreModule::CORE_MODULES.each do |cm|
        cm.children.each {|child| cm.child_association_name(child)}
      end
    end
  end
end

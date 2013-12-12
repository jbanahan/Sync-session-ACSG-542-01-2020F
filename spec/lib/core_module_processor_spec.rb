describe OpenChain::CoreModuleProcessor do

  describe "validate_and_save_module" do
    before :each do 
      @object = Product.new :unique_identifier => "unique_id"
      User.current = Factory(:user)
    end

    after :each do
      User.current = nil
    end

    it "should run module validations and save object" do
      # Create at least one rule that will result in a validation being run
      p = Product.new
      FieldValidatorRule.create! starts_with: "unique", module_type: "Product", model_field_uid: "prod_uid"

      # Create a custom field to ensure they're being parsed
      prod_cd = Factory(:custom_definition,:module_type=>'Product',:data_type=>:string)
      params = {'product_cf'=>{"#{prod_cd.id}" => 'custom'}, 'product'=>{"unique_identifier" => "unique_id"}}

      succeed = nil
      succeed_lambda = -> a {succeed = true}
      before_validate = false
      before_validate = -> a {before_validate = true}
      described_class.validate_and_save_module params, p, params['product'], succeed_lambda, nil

      p.reload
      p.unique_identifier.should eq "unique_id"
      p.get_custom_value(prod_cd).value.should eq "custom"

      before_validate.should be_true
      succeed.should be_true

      EntitySnapshot.first.recordable.id.should eq p.id
    end

    it "should run module validations and save object, skipping custom values" do
      # Create at least one rule that will result in a validation being run
      p = Product.new
      FieldValidatorRule.create! starts_with: "unique", module_type: "Product", model_field_uid: "prod_uid"

      # Create a custom field to ensure they're being parsed
      prod_cd = Factory(:custom_definition,:module_type=>'Product',:data_type=>:string)
      params = {'product_cf'=>{"#{prod_cd.id}" => 'custom'}, 'product'=>{"unique_identifier" => "unique_id"}}

      succeed = nil
      succeed_lambda = -> a {succeed = true}
      described_class.validate_and_save_module params, p, params['product'], succeed_lambda, nil, parse_custom_fields: false

      p.reload
      p.unique_identifier.should eq "unique_id"
      p.get_custom_value(prod_cd).value.should be_nil

      succeed.should be_true
    end

    it "should run module validations and save object, passing snapshot to success lambda" do
      p = Product.new
      params = {"unique_identifier" => "unique_id"}

      succeed = nil
      snapshot = nil
      succeed_lambda = -> p,s {succeed = true; snapshot = s}
      described_class.validate_and_save_module params, p, params, succeed_lambda, nil
      succeed.should be_true
      EntitySnapshot.first.id.should eq snapshot.id
    end

    it "should catch validation failures and pass them to the fail lambda" do
      p = Product.new
      FieldValidatorRule.create! starts_with: "not_unique", module_type: "Product", model_field_uid: "prod_uid"
      params = {"unique_identifier" => "unique_id"}

      failed = nil
      errors = nil
      fail_lambda = -> o, e {failed = true; errors = e}

      described_class.validate_and_save_module params, p, params, nil, fail_lambda

      failed.should be_true
      errors[:base].should have(1).item
      errors[:base].first.should  include "Unique Identifier must start with"
    end

    it "should forecast piece sets" do
      ol = Factory(:order_line)
      o = ol.order

      params = {"order_number" => "po"}
      set = ol.piece_sets.create! :quantity => 10
      PieceSet.any_instance.should_receive(:create_forecasts)

      succeed = nil
      snapshot = nil
      succeed_lambda = -> o,s {succeed = true; snapshot = s}
      described_class.validate_and_save_module params, o, params, succeed_lambda, nil
      succeed.should be_true
      EntitySnapshot.first.id.should eq snapshot.id
    end
  end
end
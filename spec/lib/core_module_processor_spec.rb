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
      params = {'product'=>{"prod_uid" => "unique_id", prod_cd.model_field_uid.to_s => "custom"}}

      succeed = nil
      succeed_lambda = -> a {succeed = true}
      described_class.validate_and_save_module params, p, params['product'], User.current, succeed_lambda, nil

      p.reload
      p.unique_identifier.should eq "unique_id"
      p.get_custom_value(prod_cd).value.should eq "custom"

      succeed.should be_true

      EntitySnapshot.first.recordable.id.should eq p.id
    end

    it "should run module validations and save object, skipping custom values" do
      # Create at least one rule that will result in a validation being run
      p = Product.new
      FieldValidatorRule.create! starts_with: "unique", module_type: "Product", model_field_uid: "prod_uid"

      # Create a custom field to ensure they're being parsed
      prod_cd = Factory(:custom_definition,:module_type=>'Product',:data_type=>:string)
      params = {'product'=>{"prod_uid" => "unique_id", prod_cd.model_field_uid.to_s => "custom"}}

      succeed = nil
      succeed_lambda = -> a {succeed = true}
      described_class.validate_and_save_module params, p, params['product'], User.current, succeed_lambda, nil, parse_custom_fields: false

      p.reload
      p.unique_identifier.should eq "unique_id"
      p.get_custom_value(prod_cd).value.should be_nil

      succeed.should be_true
    end

    it "should run module validations and save object, passing snapshot to success lambda" do
      p = Product.new
      params = {"prod_uid" => "unique_id"}

      succeed = nil
      snapshot = nil
      succeed_lambda = -> p,s {succeed = true; snapshot = s}
      described_class.validate_and_save_module params, p, params, User.current, succeed_lambda, nil
      succeed.should be_true
      EntitySnapshot.first.id.should eq snapshot.id
    end

    it "should catch validation failures and pass them to the fail lambda" do
      p = Product.new
      FieldValidatorRule.create! starts_with: "not_unique", module_type: "Product", model_field_uid: "prod_uid"
      params = {"prod_uid" => "unique_id"}

      failed = nil
      errors = nil
      fail_lambda = -> o, e {failed = true; errors = e}

      described_class.validate_and_save_module params, p, params, User.current, nil, fail_lambda

      failed.should be_true
      errors[:base].should have(1).item
      errors[:base].first.should  include "Unique Identifier must start with"
    end

    it "creates new child objects" do
      p = Product.new

      # Create a custom field to ensure they're being parsed
      country = Factory(:country)
      prod_cd = Factory(:custom_definition, :module_type=>'Product',:data_type=>:string)
      
      params = {
        'product'=> {
          'prod_uid' => 'unique_id',
          prod_cd.model_field_uid.to_s => "custom",
          'classifications_attributes' => {'0' => {
            'class_cntry_iso' => country.iso_code,
            'tariff_records_attributes' => {'0' => {
              'hts_line_number' => '5',
              'hts_hts_1' => '1234.56.7890'
              }}
          }}
        }
      }

      succeed = nil
      succeed_lambda = -> a {succeed = true}
      described_class.validate_and_save_module params, p, params['product'], User.current, succeed_lambda, nil

      expect(succeed).to be_true
      expect(EntitySnapshot.first.recordable).to eq p

      p.reload
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(prod_cd).value).to eq "custom"

      expect(p.classifications.size).to eq 1
      cl = p.classifications.first
      expect(cl.country.iso_code).to eq country.iso_code

      expect(cl.tariff_records.size).to eq 1
      tr = cl.tariff_records.first
      expect(tr.line_number).to eq 5
      expect(tr.hts_1).to eq "1234567890"
    end

    it "updates existing child objects" do
      tr = Factory(:tariff_record)
      cl = tr.classification
      p = cl.product

      country = Factory(:country)
      prod_cd = Factory(:custom_definition, :module_type=>'Product',:data_type=>:string)

      params = {
        'product'=> {
          'id' => p.id.to_s,
          'prod_uid' => 'unique_id',
          prod_cd.model_field_uid.to_s => "custom",
          'classifications_attributes' => {'0' => {
            'id' => cl.id.to_s,
            # This is actually updating the country, which won't really happen in usage, but there's no 
            # technical reason that it shouldn't work behind the scenese
            'class_cntry_iso' => country.iso_code,
            'tariff_records_attributes' => {'0' => {
              'id' => tr.id.to_s,
              'hts_hts_1' => '9876.54.3210'
              }}
          }}
        }
      }

      succeed = nil
      succeed_lambda = -> a {succeed = true}
      described_class.validate_and_save_module params, p, params['product'], User.current, succeed_lambda, nil

      expect(succeed).to be_true
      expect(EntitySnapshot.first.recordable).to eq p

      p.reload
      expect(p.unique_identifier).to eq "unique_id"
      expect(p.get_custom_value(prod_cd).value).to eq "custom"

      expect(p.classifications.size).to eq 1
      found_cl = p.classifications.first
      expect(found_cl.id).to eq cl.id
      expect(found_cl.country.iso_code).to eq country.iso_code

      expect(found_cl.tariff_records.size).to eq 1
      found_tr = found_cl.tariff_records.first
      expect(found_tr.id).to eq tr.id
      expect(found_tr.hts_1).to eq "9876543210"
    end

    it "deletes child records" do
      tr = Factory(:tariff_record)
      cl = tr.classification
      p = cl.product

      country = Factory(:country)
      prod_cd = Factory(:custom_definition, :module_type=>'Product',:data_type=>:string)

      params = {
        'product'=> {
          'id' => p.id.to_s,
          'prod_uid' => 'unique_id',
          'classifications_attributes' => {'0' => {
            'id' => cl.id.to_s,
            '_destroy' => 'true'
          }}
        },
      }

      succeed = nil
      succeed_lambda = -> a {succeed = true}
      before_validate = false
      before_validate = -> a {before_validate = true}
      described_class.validate_and_save_module params, p, params['product'], User.current, succeed_lambda, nil
      expect(succeed).to be_true

      p.reload
      expect(p.classifications.size).to eq 0
    end

    it "it deletes, updates, and adds child records" do
      tr = Factory(:tariff_record)
      cl = tr.classification
      p = cl.product

      cl2 = Factory(:classification, product: p)
      tr2 = Factory(:tariff_record, classification: cl2)
      country = Factory(:country)
      country2 = Factory(:country)

      params = {
        'product'=> {
          'id' => p.id,
          'prod_uid' => 'unique_id',
          'classifications_attributes' => {
            '0' => {
              'id' => cl.id,
              '_destroy' => '1'
            },
            '1' => {
              'id' => cl2.id,
              'class_cntry_iso' => country.iso_code,
              'tariff_records_attributes' => {'0' => {
                'id' => tr2.id,
                'hts_hts_1' => '9876.54.3210'
                }}
              },
            '2' => {
              'class_cntry_iso' => country2.iso_code,
              'tariff_records_attributes' => {'0' => {
                'hts_line_number' => '3',
                'hts_hts_1' => '1234567890'
                }}
              }
            }
        }
      }

      succeed = nil
      succeed_lambda = -> a {succeed = true}
      before_validate = false
      before_validate = -> a {before_validate = true}
      described_class.validate_and_save_module params, p, params['product'], User.current, succeed_lambda, nil
      expect(succeed).to be_true

      p.reload
      expect(p.classifications.size).to eq 2

      c_1 = p.classifications.first
      expect(c_1.country).to eq country
      expect(c_1.tariff_records.first.hts_1).to eq "9876543210"

      c_2 = p.classifications.second
      expect(c_2.country).to eq country2
      expect(c_2.tariff_records.first.hts_1).to eq "1234567890"
    end

    it "it deletes, updates, and adds child records using standard attribute nesting" do
      tr = Factory(:tariff_record)
      cl = tr.classification
      p = cl.product

      cl2 = Factory(:classification, product: p)
      tr2 = Factory(:tariff_record, classification: cl2)
      country = Factory(:country)
      country2 = Factory(:country)

      params = {
        product: {
          id: p.id,
          prod_uid: 'unique_id',
          classifications_attributes: [
            {
              id: cl.id,
              _destroy: '1'
            },
            {
              id: cl2.id,
              class_cntry_iso: country.iso_code,
              tariff_records_attributes: [{
                id: tr2.id,
                hts_hts_1: '9876.54.3210'
              }]
            },
            {
              class_cntry_iso: country2.iso_code,
              tariff_records_attributes: [{
                hts_line_number: '3',
                hts_hts_1: '1234567890'
              }]
            }
          ]
        }
      }

      succeed = nil
      succeed_lambda = -> a {succeed = true}
      described_class.validate_and_save_module params, p, params[:product], User.current, succeed_lambda, nil
      expect(succeed).to be_true

      p.reload
      expect(p.classifications.size).to eq 2

      c_1 = p.classifications.first
      expect(c_1.country).to eq country
      expect(c_1.tariff_records.first.hts_1).to eq "9876543210"
      c_2 = p.classifications.second
      expect(c_2.country).to eq country2
      expect(c_2.tariff_records.first.hts_1).to eq "1234567890"
    end

    it "errors if import failure occurs" do
      p = Factory(:product, unique_identifier: "ID")
      params = {
        product: {
          id: p.id,
          prod_uid: 'unique_id'
        }
      }

      result = "Failed"
      result.stub(:error?).and_return true
      ModelField.find_by_uid(:prod_uid).should_receive(:process_import).with(p, "unique_id", User.current).and_return result

      fail_object= nil
      fail_errors = nil
      fail_lambda = lambda {|base_object, errors| fail_object = base_object; fail_errors = errors}
      described_class.validate_and_save_module params, p, params[:product], User.current, nil, fail_lambda

      expect(fail_object).to eq p
      expect(fail_errors).to eq p.errors
      expect(p.unique_identifier).to eq "ID"
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
      described_class.validate_and_save_module params, o, params, User.current, succeed_lambda, nil
      succeed.should be_true
      EntitySnapshot.first.id.should eq snapshot.id
    end
  end

  describe "bulk_objects" do
    before :each do
      @cm = CoreModule::PRODUCT
      @obj = Factory(:product)
      @obj2 = Factory(:product)
    end

    it "finds, locks and yields objects given an array of primary keys" do
      yielded = []
      good_count = nil

      Lock.should_receive(:acquire).with("Product-#{@obj.unique_identifier}", times: 5, yield_in_transaction: false).and_yield
      Lock.should_receive(:acquire).with("Product-#{@obj2.unique_identifier}", times: 5, yield_in_transaction: false).and_yield

      described_class.bulk_objects(@cm, nil, [@obj.id, @obj2.id]) do |gc, obj|
        yielded << obj
        good_count = gc
      end

      expect(yielded).to eq [@obj, @obj2]
      expect(good_count).to eq 2
    end

    it "finds, locks and yields objects given a hash of of primary keys" do
      yielded = []
      good_count = nil

      Lock.should_receive(:acquire).with("Product-#{@obj.unique_identifier}", times: 5, yield_in_transaction: false).and_yield
      Lock.should_receive(:acquire).with("Product-#{@obj2.unique_identifier}", times: 5, yield_in_transaction: false).and_yield

      described_class.bulk_objects(@cm, nil, {o1: @obj.id, o2: @obj2.id}) do |gc, obj|
        yielded << obj
        good_count = gc
      end

      expect(yielded).to eq [@obj, @obj2]
      expect(good_count).to eq 2
    end

    it "finds, locks and yields objects referenced by a search run id" do
      yielded = []
      good_count = nil

      # Just set object keys in the search run ahead of time..this is a little white-boxy, but it works.
      sr = SearchRun.new
      sr.instance_variable_set("@object_keys", [@obj.id, @obj2.id])

      Lock.should_receive(:acquire).with("Product-#{@obj.unique_identifier}", times: 5, yield_in_transaction: false).and_yield
      Lock.should_receive(:acquire).with("Product-#{@obj2.unique_identifier}", times: 5, yield_in_transaction: false).and_yield

      described_class.bulk_objects(@cm, nil, [@obj.id, @obj2.id]) do |gc, obj|
        yielded << obj
        good_count = gc
      end

      expect(yielded).to eq [@obj, @obj2]
      expect(good_count).to eq 2
    end
  end
end
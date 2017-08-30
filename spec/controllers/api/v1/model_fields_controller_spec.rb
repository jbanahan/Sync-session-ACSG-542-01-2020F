require 'spec_helper'
require 'digest/md5'

describe Api::V1::ModelFieldsController do

  before :each do
    @user = Factory(:user, product_view: true, username: 'joeuser')
    allow_api_access(@user)
  end

  describe "index" do
    it "should get record types (core modules)" do
      expect(get :index).to be_success

      h = JSON.parse(response.body)
      product_rt = h['recordTypes'].find {|rt| rt['uid']=='Product'}
      expect(product_rt['label']).to eq 'Product'
    end
    it "should not get record types that the current user can't view" do
      expect(CoreModule::ORDER).to receive(:view?).with(@user).and_return(false)

      expect(get :index).to be_success

      h = JSON.parse(response.body)
      order_rt = h['recordTypes'].find {|rt| rt['uid']=='Order'}
      expect(order_rt).to be_nil
    end
    it "should get model fields" do

      expect(get :index).to be_success

      h = JSON.parse(response.body)
      prod_uid = h['fields'].find {|fld| fld['uid']=='prod_uid'}
      expect(prod_uid['label']).to eq 'Unique Identifier'
      expect(prod_uid['data_type']).to eq 'string'
      expect(prod_uid['record_type_uid']).to eq 'Product'
    end
    it "should not get prefixes on labels" do
      expect(get :index).to be_success

      h = JSON.parse(response.body)
      fld = h['fields'].find {|f| f['uid']=='class_comp_cnt'}
      expect(fld['label']).to eq "Component Count"
    end
    it "should not get model fields that the current user can't see" do
      allow_any_instance_of(ModelField).to receive(:can_view?).with(@user).and_return false
      allow(CoreModule::ENTRY).to receive(:view?).and_return(true)
      allow_any_instance_of(Company).to receive(:broker?).and_return(false)

      expect(get :index).to be_success

      h = JSON.parse(response.body)
      duty_due = h['fields'].find {|fld| fld['uid']=='ent_duty_due_date'}
      expect(duty_due).to be_nil
    end
    it "should get read_only flag" do
      expect(get :index).to be_success

      h = JSON.parse(response.body)
      changed_at = h['fields'].find {|fld| fld['uid']=='prod_changed_at'}
      expect(changed_at['read_only']).to be_truthy
    end
    it "should get autocomplete info" do
      expect(get :index).to be_success
      h = JSON.parse(response.body)
      div_name = h['fields'].find {|fld| fld['uid']=='prod_div_name'}
      expected_auto_complete = {'url'=>'/api/v1/divisions/autocomplete?n=','field'=>'val'}
      expect(div_name['autocomplete']).to eq expected_auto_complete
    end

    it "should flag remote validate" do
      fvr = instance_double(FieldValidatorRule)
      expect(ModelField.find_by_uid(:prod_name)).to receive(:field_validator_rule).and_return fvr
      expect(fvr).to receive(:requires_remote_validation?).and_return true
      expect(fvr).to receive(:one_of_array).and_return ["A", "X", "C"]

      expect(get :index).to be_success
      h = JSON.parse(response.body)
      mf = h['fields'].find {|fld| fld['uid']=='prod_name'}
      expect(mf['remote_validate']).to eq true
      expect(mf['select_options']).to eq [["A", "A"], ["X", "X"], ["C", "C"]]

      mf = h['fields'].find {|fld| fld['uid']=='prod_uid'}
      expect(mf['remote_validate']).to be_nil
    end

    it "uses select options from field validator rule" do
      fvr = instance_double(FieldValidatorRule)
      expect(ModelField.find_by_uid(:prod_name)).to receive(:field_validator_rule).and_return fvr
      expect(fvr).to receive(:requires_remote_validation?).and_return false
      expect(fvr).to receive(:one_of_array).and_return ["A", "X", "C"]

      expect(get :index).to be_success
      h = JSON.parse(response.body)
      mf = h['fields'].find {|fld| fld['uid']=='prod_name'}
      expect(mf['select_options']).to eq [["A", "A"], ["X", "X"], ["C", "C"]]
    end

    it "should return cache key" do
      mfload = 10.minutes.ago
      company_updated_at = 1.hour.ago
      user_updated_at = 1.day.ago

      expect(ModelField).to receive(:last_loaded).twice.and_return(mfload)
      expect_any_instance_of(Company).to receive(:updated_at).and_return(company_updated_at)
      expect_any_instance_of(User).to receive(:updated_at).twice.and_return(user_updated_at)

      expected_cache = Digest::MD5.hexdigest "#{@user.username}#{mfload.to_s}#{company_updated_at.to_i}#{user_updated_at.to_i}"

      expect(get :index).to be_success

      h = JSON.parse(response.body)
      expect(h['cache_key']).to eq expected_cache
    end
    it "should get select_options" do
      EntityType.create!(module_type:'Product',name:'PT')

      expect(get :index).to be_success

      h = JSON.parse(response.body)
      fld = h['fields'].find {|f| f['uid']=='prod_ent_type'}
      expect(fld['select_options']).to eq [['PT','PT']]
    end
    it "should get cdef_uid" do
      cd = Factory(:custom_definition,module_type:'Product',cdef_uid:'xyz')
      ModelField.reload
      expect(get :index).to be_success

      h = JSON.parse(response.body)
      fld = h['fields'].find {|f| f['uid']=="*cf_#{cd.id}"}
      expect(fld['cdef_uid']).to eq 'xyz'
    end
  end

  describe "cache_key" do
    it "should get cache_key" do
      mfload = 10.minutes.ago
      company_updated_at = 1.hour.ago
      user_updated_at = 1.day.ago

      expect(ModelField).to receive(:last_loaded).and_return(mfload)
      expect_any_instance_of(Company).to receive(:updated_at).and_return(company_updated_at)
      expect_any_instance_of(User).to receive(:updated_at).and_return(user_updated_at)

      expected_cache = Digest::MD5.hexdigest "#{@user.username}#{mfload.to_s}#{company_updated_at.to_i}#{user_updated_at.to_i}"

      expect(get :cache_key).to be_success

      expect(JSON.parse(response.body)).to eq({'cache_key'=>expected_cache})
    end
  end
end

require 'spec_helper'

describe QuickSearchController do
  before :each do 
    MasterSetup.get.update_attributes(vendor_management_enabled: true, entry_enabled: true)
    c = Factory(:company,:master=>true)
    @u = Factory(:user, vendor_view: true, entry_view: true, company: c)

    sign_in_as @u
  end

  context :show do 
    it "should put appropriate modules into @available_modules" do
      to_show = [CoreModule::ENTRY,CoreModule::PRODUCT]
      described_class::FIELDS_BY_MODULE.keys.each do |cm|
        cm.stub(:view?).and_return to_show.include?(cm)
      end

      get :show, v: 'Test'

      expect(response).to be_success
      mods = assigns(:available_modules)
      expect(mods.size).to eq 2
      expect(mods).to include(CoreModule::ENTRY)
      expect(mods).to include(CoreModule::PRODUCT)
    end
  end

  context :by_module do
    it "should return result for core module" do
      cd_1 = Factory(:custom_definition, :module_type=>"Entry", :quick_searchable => true, :label=>'cfield')
      ent = Factory(:entry,:entry_number=>'12345678901')
      ent.update_custom_value! cd_1, "Test"

      expected_response = {
        'qs_result'=>{
          'module_type'=>'Entry',
          'fields'=>{},
          'vals'=>[{'id'=>ent.id}]
        }
      }
      described_class::FIELDS_BY_MODULE[CoreModule::ENTRY].each do |uid|
        mf = ModelField.find_by_uid(uid)
        expected_response['qs_result']['fields'][uid.to_s] = mf.label
        expected_response['qs_result']['vals'][0][uid.to_s] = mf.process_export(ent,nil,true)
      end
      expected_response['qs_result']['fields']["*cf_#{cd_1.id}"] = 'cfield'
      expected_response['qs_result']['vals'][0]["*cf_#{cd_1.id}"] = 'Test'
      expected_response['qs_result']['vals'][0]['view_url'] = "/entries/#{ent.id}"
      expected_response['qs_result']['search_term'] = '123'
      
      get :by_module, module_type:'Entry', v: '123'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j).to eq expected_response
    end

    it "should return a result for Vendor" do
      vendor = Factory(:company, :name=>'Company', vendor: true, system_code: "CODE")
      mfid = "cmp_name"
      get :by_module, module_type: "Company", v: 'Co'
      expect(response).to be_success
      r = JSON.parse response.body
      expect(r).to eq({
        'qs_result' => {
          'module_type' => 'Company',
          'fields' => {
            "cmp_name" => "Name"
          },
          'vals' => [{'id' => vendor.id, 'view_url' => "/vendors/#{vendor.id}", "cmp_name" => vendor.name}],
          'search_term' => "Co"
        }
      })
    end

    it "should 404 if user doesn't have permission" do
      CoreModule::ENTRY.stub(:view?).and_return false
      expect {get :by_module, module_type:'Entry', v: '123'}.to raise_error ActionController::RoutingError
    end
    it "should 404 on bad :module_type" do
      expect {get :by_module, module_type:'Bad', v: '123'}.to raise_error ActionController::RoutingError
    end
  end
end

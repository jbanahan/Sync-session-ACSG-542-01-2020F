describe QuickSearchController do

  let! (:master_setup) {
    ms = stub_master_setup
    allow(ms).to receive(:broker_invoice_enabled).and_return true
    allow(ms).to receive(:broker_invoice_enabled?).and_return true
    allow(ms).to receive(:classification_enabled?).and_return true
    allow(ms).to receive(:customs_statements_enabled?).and_return true
    allow(ms).to receive(:delivery_enabled?).and_return true
    allow(ms).to receive(:drawback_enabled?).and_return true
    allow(ms).to receive(:entry_enabled?).and_return true
    allow(ms).to receive(:entry_enabled).and_return true
    allow(ms).to receive(:invoices_enabled?).and_return true
    allow(ms).to receive(:order_enabled?).and_return true
    allow(ms).to receive(:sales_order_enabled?).and_return true
    allow(ms).to receive(:security_filing_enabled?).and_return true
    allow(ms).to receive(:shipment_enabled?).and_return true
    allow(ms).to receive(:trade_lane_enabled?).and_return true
    allow(ms).to receive(:variant_enabled?).and_return true
    allow(ms).to receive(:vendor_management_enabled?).and_return true
    allow(ms).to receive(:vendor_management_enabled).and_return true
    allow(ms).to receive(:vfi_invoice_enabled?).and_return true
    ms
  }

  before :each do
    c = Factory(:company, :master=>true, :show_business_rules=>true)
    @u = Factory(:user, vendor_view: true, entry_view: true, company: c, broker_invoice_view: true)

    sign_in_as @u
  end

  context "show" do
    it "should put appropriate modules into @available_modules" do
      expect_any_instance_of(described_class).to receive(:core_modules_with_quicksearch_fields).with(@u).and_return([CoreModule::ENTRY, CoreModule::PRODUCT])

      get :show, v: 'Test'

      expect(response).to be_success
      mods = assigns(:available_modules)
      expect(mods.size).to eq 2
      expect(mods).to include(CoreModule::ENTRY)
      expect(mods).to include(CoreModule::PRODUCT)
    end
  end

  context "by_module" do
    it "should return result for core module" do
      allow_any_instance_of(CoreModule).to receive(:quicksearch_extra_fields).and_return []
      cd_1 = Factory(:custom_definition, :module_type=>"Entry", :quick_searchable => true, :label=>'cfield')
      ent = Factory(:entry, :entry_number=>'12345678901')
      ent.update_custom_value! cd_1, "Test"
      bvre_1 = Factory(:business_validation_result, state: "Pass", validatable: ent)
      bvre_2 = Factory(:business_validation_result, state: "Fail", validatable: ent)

      expected_response = {
        'qs_result'=>{
          'module_type'=>'Entry',
          'adv_search_path'=>'entries/?force_search=true',
          'fields'=>{},
          'vals'=>[{'id'=>ent.id}],
          'extra_fields'=>{},
          'extra_vals'=>{ent.id.to_s => {}},
          'attachments'=>{ent.id.to_s => []},
          'business_validation_results'=>{ent.id.to_s => {'id' => bvre_2.id, 'state' => 'Fail', 'type' => 'Entry', 'validation_link' => validation_results_entry_path(ent) }}
        }
      }
      CoreModule::ENTRY.quicksearch_fields.each do |uid|
        mf = ModelField.find_by_uid(uid)
        expected_response['qs_result']['fields'][uid.to_s] = mf.label
        expected_response['qs_result']['vals'][0][uid.to_s] = mf.process_export(ent, nil, true)
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

    it "returns a limited search, if specified" do
      Factory(:entry, :broker_reference => "123")
      Factory(:entry, :entry_number => "123")
      expect(CoreModule::ENTRY).to receive(:quicksearch_sort_by).at_least(1).times.and_return "entries.file_logged_date"

      get :by_module, module_type:'Entry', v: '123', limit_fields: 'ent_entry_num'
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j["qs_result"]["vals"].count).to eq 1

      expect(j["qs_result"]["vals"].first["ent_entry_num"]).to eq "123"
    end

    it "sorts results by qualified field name specified in Core Module" do
      Factory(:entry, :broker_reference => "123_second", :file_logged_date => DateTime.now - 1)
      Factory(:entry, :broker_reference => "123_last", :file_logged_date => DateTime.now - 2)
      Factory(:entry, :broker_reference => "123_first", :file_logged_date => DateTime.now)
      expect(CoreModule::ENTRY).to receive(:quicksearch_sort_by).at_least(1).times.and_return "entries.file_logged_date"

      get :by_module, module_type:'Entry', v: '123'
      expect(response).to be_success
      j = JSON.parse response.body

      expect(j["qs_result"]["vals"].first["ent_brok_ref"]).to eq "123_first"
      expect(j["qs_result"]["vals"].second["ent_brok_ref"]).to eq "123_second"
      expect(j["qs_result"]["vals"].third["ent_brok_ref"]).to eq "123_last"
    end

    it "should return a result for Vendor" do
      allow_any_instance_of(CoreModule).to receive(:quicksearch_extra_fields).and_return []
      vendor = Factory(:company, :name=>'Company', vendor: true, system_code: "CODE")
      get :by_module, module_type: "Company", v: 'Co'
      expect(response).to be_success
      r = JSON.parse response.body

      expect(r['qs_result']['vals']).to eq [{'id' => vendor.id, 'view_url' => "/vendors/#{vendor.id}", "cmp_name" => vendor.name, "cmp_sys_code" => vendor.system_code}]
      expect(r['qs_result']['module_type']).to eq "Company"
      expect(r['qs_result']['fields']).to eq({"cmp_name" => "Name", "cmp_sys_code" => "System Code"})
    end

    it "should return a result for BrokerInvoice for an importer company" do
      allow_any_instance_of(CoreModule).to receive(:quicksearch_extra_fields).and_return []
      c = Factory(:company, importer: true)
      user = Factory(:user, company: c, broker_invoice_view: true)
      sign_in_as user

      entry = Factory(:entry, broker_reference: "REFERENCE", importer: c)
      broker_invoice = Factory(:broker_invoice, entry: entry, invoice_number: "INV#")

      get :by_module, module_type: "BrokerInvoice", v: 'INV#'
      expect(response).to be_success
      r = JSON.parse response.body
      expect(r['qs_result']['module_type']).to eq "BrokerInvoice"
      expect(r['qs_result']['fields']).to eq({"bi_invoice_number" => "Invoice Number", "bi_brok_ref" => "Broker Reference"})
      expect(r['qs_result']['vals']).to eq [{'id' => broker_invoice.id, 'view_url' => "/broker_invoices/#{broker_invoice.id}", "bi_brok_ref" => "REFERENCE", "bi_invoice_number" => "INV#"}]
    end

    it "returns extra fields" do
      e = Factory(:entry, location_of_goods: "Cleveland", importer_tax_id: "TAX_ID 1")
      e2 = Factory(:entry, location_of_goods: "Cleveland", importer_tax_id: "TAX_ID 2")
      allow(Entry).to receive(:can_view_importer?).and_return true
      allow_any_instance_of(CoreModule).to receive(:quicksearch_fields).and_return [:ent_location_of_goods]
      allow_any_instance_of(CoreModule).to receive(:quicksearch_extra_fields).and_return [:ent_importer_tax_id]
      get :by_module, module_type: "Entry", v: "Cleveland"
      expect(response).to be_success
      r = JSON.parse response.body

      expect(r['qs_result']['extra_fields']).to eq({'ent_importer_tax_id' => "Importer Tax ID"})
      expect(r['qs_result']['extra_vals']).to eq({ e.id.to_s => {'ent_importer_tax_id' => "TAX_ID 1"}, e2.id.to_s => {'ent_importer_tax_id' => "TAX_ID 2"}})
    end

    it "overrides extra fields if specified" do
      e = Factory(:entry, location_of_goods: "Cleveland", importer_tax_id: "TAX_ID 1", carrier_code: "CARRIER 1")
      e2 = Factory(:entry, location_of_goods: "Cleveland", importer_tax_id: "TAX_ID 2", carrier_code: "CARRIER 2")
      allow(Entry).to receive(:can_view_importer?).and_return true
      allow_any_instance_of(CoreModule).to receive(:quicksearch_fields).and_return [:ent_location_of_goods]
      allow_any_instance_of(CoreModule).to receive(:quicksearch_extra_fields).and_return [:ent_importer_tax_id]
      get :by_module, module_type: "Entry", v: "Cleveland", override_extra_fields: "ent_carrier_code"
      expect(response).to be_success
      r = JSON.parse response.body

      expect(r['qs_result']['extra_fields']).to eq({'ent_carrier_code' => "Carrier Code"})
      expect(r['qs_result']['extra_vals']).to eq({ e.id.to_s => {'ent_carrier_code' => "CARRIER 1"}, e2.id.to_s => {'ent_carrier_code' => "CARRIER 2"}})
    end

    it "suppresses attachments and rule results if specified" do
      allow_any_instance_of(CoreModule).to receive(:quicksearch_extra_fields).and_return []
      ent = Factory(:entry, :entry_number=>'12345678901')

      Factory(:business_validation_result, state: "Pass", validatable: ent)
      Factory(:business_validation_result, state: "Fail", validatable: ent)

      get :by_module, module_type:'Entry', v: '123', hide_attachments: "true", hide_business_rules: "true"
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['qs_result']['attachments']).to eq({})
      expect(j['qs_result']['business_validation_results']).to eq({})
    end

    it "should 404 if user doesn't have permission" do
      allow(CoreModule::ENTRY).to receive(:view?).and_return false
      expect {get :by_module, module_type:'Entry', v: '123'}.to raise_error ActionController::RoutingError
    end
    it "should 404 on bad :module_type" do
      expect {get :by_module, module_type:'Bad', v: '123'}.to raise_error ActionController::RoutingError
    end
  end
end

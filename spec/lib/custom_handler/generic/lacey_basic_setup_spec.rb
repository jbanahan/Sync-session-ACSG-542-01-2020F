describe OpenChain::CustomHandler::Generic::LaceyBasicSetup do
  let :base_obj do
    described_class.new("Joe Wood","jwood",short_name:'J-Wood')
  end
  let :cdefs do
    described_class.prep_custom_definitions([:ord_approved_to_ship_by,:ord_approved_to_ship_date])
  end
  
  describe '#run' do
    it "should prep master company and master setup" do
      expect(base_obj).to receive(:prep_master_company).ordered
      expect(base_obj).to receive(:prep_master_setup).ordered
      expect(base_obj).to receive(:prep_groups).ordered
      expect(base_obj).to receive(:prep_user_templates).ordered
      expect(base_obj).to receive(:prep_search_table_configs).ordered
      expect(base_obj).to receive(:prep_state_toggle_buttons).ordered
      expect(base_obj).to receive(:prep_business_validation_templates).ordered
      base_obj.run
    end
  end
  
  describe '#prep_master_company' do
    it "should set company name and importer flag" do
      expect{base_obj.prep_master_company}.to change(Company,:count).from(0).to(1)
      expect(Company.where(master:true,importer:true,name:'Joe Wood').first).to_not be_nil
    end
  end
  
  describe '#prep_master_setup' do
    it "should set system_code and modules" do
      base_obj.prep_master_setup
      expect(MasterSetup.count).to eq 1
      ms = MasterSetup.get
      expect(ms.system_code).to eq 'jwood'
      expect(ms.order_enabled).to be_truthy
      expect(ms.vendor_management_enabled).to be_truthy
    end
  end
  
  describe '#prep_groups' do
    let :expected_system_codes do
      ['ORDERACCEPT','ORDERAPPROVE'].sort
    end
    let :total_group_count do
      expected_system_codes.size
    end
    it "should create groups" do
      expect{base_obj.prep_groups}.to change(Group,:count).from(0).to(total_group_count)
      expect(Group.pluck(:system_code).sort).to eq expected_system_codes
    end
    it "should use group that already exists" do
      Factory(:group,system_code:expected_system_codes.first)
      expect{base_obj.prep_groups}.to change(Group,:count).from(1).to(total_group_count)
      expect(Group.pluck(:system_code).sort).to eq expected_system_codes
    end
  end
  describe '#prep_user_templates' do
    let :user_template_count do
      2
    end
    it "should make user template for base users" do
      expect{base_obj.prep_user_templates}.to change(UserTemplate,:count).from(0).to(user_template_count)
      t = UserTemplate.find_by name: "Standard J-Wood User"
      h = JSON.parse(t.template_json)
      expect(h['permissions'].sort).to eq ['order_view','order_comment','order_attach','product_view','product_comment','product_attach','vendor_view','vendor_comment','vendor_attach'].sort
      expect(h['password_reset']).to be_truthy
      expect(h['email_new_messages']).to be_truthy
    end
    it "should make user template for vendors" do
      expect{base_obj.prep_user_templates}.to change(UserTemplate,:count).from(0).to(user_template_count)
      t = UserTemplate.find_by name: "Standard Vendor User"
      h = JSON.parse(t.template_json)
      expect(h['permissions'].sort).to eq ['order_view','order_comment','order_attach','product_view'].sort
      expect(h['password_reset']).to be_truthy
      expect(h['email_new_messages']).to be_truthy
      expect(h['portal_mode']).to eq 'vendor'
      expected_event_subscriptions = [
        {'event_type'=>'ORDER_CREATE','system_message'=>true},
        {'event_type'=>'ORDER_UNACCEPT','system_message'=>true},
        {'event_type'=>'ORDER_COMMENT_CREATE','system_message'=>true}
      ]
      expect(h['event_subscriptions']).to eq expected_event_subscriptions
      expect(h['groups']).to eq ['ORDERACCEPT']
    end
  end
  
  describe '#prep_search_table_configs' do
    let :total_search_table_configs do
      7
    end
    describe 'vendor-product' do
      it "should create All Products" do
        expect{base_obj.prep_search_table_configs}.to change(SearchTableConfig,:count).from(0).to(total_search_table_configs)
        stc = SearchTableConfig.where(page_uid:'vendor-product',name:'All Products').first
        expected_hash = {"columns"=>["prodven_puid","prodven_pname"],"criteria"=>[],"sorts"=>[{"field"=>"prodven_puid","order"=>"A"}]}
        expect(stc.config_hash).to eq expected_hash
      end
    end
    describe 'vendor-order' do
      it "should create All Orders" do
        expect{base_obj.prep_search_table_configs}.to change(SearchTableConfig,:count).from(0).to(total_search_table_configs)
        stc = SearchTableConfig.where(page_uid:'vendor-order',name:'All Orders').first
        expected_hash = {"columns"=>["ord_ord_num","ord_ord_date","ord_accepted_at",cdefs[:ord_approved_to_ship_date].model_field_uid.to_s],"criteria"=>[],"sorts"=>[{"field"=>"ord_ord_num","order"=>"D"}]}
        expect(stc.config_hash).to eq expected_hash
      end
    end
    describe 'vendor-address' do
      it "should create All Addresses" do
        expect{base_obj.prep_search_table_configs}.to change(SearchTableConfig,:count).from(0).to(total_search_table_configs)
        stc = SearchTableConfig.where(page_uid:'vendor-address',name:'All Addresses').first
        expected_hash = {"columns"=>["add_name","add_full_address","add_shipping"],"sorts"=>[{"field"=>"add_name","order"=>"A"}]}
        expect(stc.config_hash).to eq expected_hash
      end
    end
    describe 'chain-vp-order-panel' do
      it "should create Needs To Be Accepted" do
        expect{base_obj.prep_search_table_configs}.to change(SearchTableConfig,:count).from(0).to(total_search_table_configs)
        stc = SearchTableConfig.where(page_uid:'chain-vp-order-panel',name:'Needs To Be Accepted').first
        expected_hash = {
          "columns"=>["ord_ord_num","ord_ord_date","ord_window_end","ord_rule_state"],
          "criteria"=>[{"field"=>"ord_accepted_at","operator"=>"null","val"=>""}],
          "sorts"=>[{"field"=>"ord_ord_num","order"=>"A"}]
        }
        expect(stc.config_hash).to eq expected_hash
      end
      it "should create Approved To Ship" do
        expect{base_obj.prep_search_table_configs}.to change(SearchTableConfig,:count).from(0).to(total_search_table_configs)
        stc = SearchTableConfig.where(page_uid:'chain-vp-order-panel',name:'Approved To Ship').first
        expected_hash = {
          "columns"=>["ord_ord_num","ord_ord_date","ord_window_end","ord_rule_state"],
          "criteria"=>[{"field"=>"ord_rule_state","operator"=>"eq","val"=>"Pass"}],
          "sorts"=>[{"field"=>"ord_ord_num","order"=>"A"}]
        }
        expect(stc.config_hash).to eq expected_hash
      end
      it "should create All Orders" do
        expect{base_obj.prep_search_table_configs}.to change(SearchTableConfig,:count).from(0).to(total_search_table_configs)
        stc = SearchTableConfig.where(page_uid:'chain-vp-order-panel',name:'All Orders').first
        expected_hash = {
          "columns"=>["ord_ord_num","ord_ord_date","ord_window_end","ord_accepted_at","ord_rule_state"],
          "criteria"=>[],
          "sorts"=>[{"field"=>"ord_ord_num","order"=>"A"}]
        }
        expect(stc.config_hash).to eq expected_hash
      end
      it "should create New Orders (14 Days)" do
        expect{base_obj.prep_search_table_configs}.to change(SearchTableConfig,:count).from(0).to(total_search_table_configs)
        stc = SearchTableConfig.where(page_uid:'chain-vp-order-panel',name:'New Orders (14 Days)').first
        expected_hash = {
          "columns"=>["ord_ord_num","ord_ord_date","ord_window_end","ord_accepted_at","ord_rule_state"],
          "criteria"=>[{"field"=>"ord_ord_date","operator"=>"ada","val"=>"14"}],
          "sorts"=>[{"field"=>"ord_ord_num","order"=>"A"}]
        }
        expect(stc.config_hash).to eq expected_hash
      end
    end
  end
  describe '#prep_custom_definitions' do
    it "should build :ord_approved_to_ship_by & :ord_approved_to_ship_date" do
      cd = nil
      expect{cd = base_obj.cdefs}.to change(CustomDefinition,:count).by(2)
      expect(cd.keys.sort).to eq [:ord_approved_to_ship_by,:ord_approved_to_ship_date]
    end
  end
  describe '#prep_state_toggle_buttons' do
    it "should create Order approve to ship button" do
      expect{base_obj.prep_state_toggle_buttons}.to change(StateToggleButton,:count).from(0).to(1)
      stb = StateToggleButton.where(
        module_type:'Order',
        user_custom_definition_id:cdefs[:ord_approved_to_ship_by].id,
        date_custom_definition_id:cdefs[:ord_approved_to_ship_date].id,
        permission_group_system_codes: 'ORDERAPPROVE',
        activate_text:'Approve To Ship',
        deactivate_text:'Revoke Ship Approval',
        deactivate_confirmation_text:'Are you sure you want to revoke shipping approval?'
      ).first
      expect(stb).to_not be_blank
    end
  end
  describe '#prep_business_validation_templates' do
    it "should create order business validation template" do
      expect{base_obj.prep_business_validation_templates}.to change(BusinessValidationTemplate,:count).from(0).to(1)
      bvt = BusinessValidationTemplate.where(
        name:'Base Order',
        module_type:'Order'
      ).first
      expect(bvt).to_not be_nil
      expect(bvt.business_validation_rules.count).to eq 2
      
      # Vendor accept
      bvr = BusinessValidationRule.where(
        type:'ValidationRuleFieldFormat',
        name:'Vendor Must Accept Order',
        description:'Vendor must accept purchase order.',
        fail_state:'Fail'
      ).first
      expect(JSON.parse(bvr.rule_attributes_json)).to eq JSON.parse('{"model_field_uid":"ord_accepted_at","regex":"[0-9]"}')
      
      # Client accept
      bvr = BusinessValidationRule.where(
        type:'ValidationRuleFieldFormat',
        name:"Approve To Ship",
        description:'J-Wood must approve the order to ship.',
        fail_state:'Fail'
      ).first
      expect(JSON.parse(bvr.rule_attributes_json)).to eq JSON.parse('{"model_field_uid":"'+cdefs[:ord_approved_to_ship_date].model_field_uid.to_s+'","regex":"[0-9]"}')
    end
  end
  
  describe '#prep_attachment_types' do
    it "should create attachment types" do
      expected = ['Purchase Order','Chain of Custody','PPQ','Specification','Other']
      base_obj.prep_attachment_types
      expect(AttachmentType.pluck(:name).sort).to eq expected.sort
    end
  end
end

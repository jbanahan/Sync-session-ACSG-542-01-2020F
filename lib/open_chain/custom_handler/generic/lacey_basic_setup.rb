require 'open_chain/custom_handler/generic/generic_custom_definition_support'
# Setup a new instance with the configurations to support the Lacey Basic product
module OpenChain; module CustomHandler; module Generic; class LaceyBasicSetup
  include OpenChain::CustomHandler::Generic::GenericCustomDefinitionSupport
  # Required Parameters
  #
  # `company_name` - descriptive name of company "Joe Wood Products"
  # `system_code` - target MasterSetup.get.system_code "joewood"
  # 
  # Optional Named Parameters
  # 
  # `short_name` - Short version of company name "IBM" instead of International Business Machines. If blank, defaults to `company_name`
  # 
  def initialize company_name, system_code, short_name: nil
    @company_name = company_name
    @system_code = system_code
    @short_name = short_name.blank? ? company_name : short_name
  end
  
  # run all steps
  def run
    prep_master_company
    prep_master_setup
    prep_groups
    prep_user_templates
    prep_search_table_configs
    prep_state_toggle_buttons
    prep_business_validation_templates
    ModelField.reload true
    true
  end
  
  def prep_master_company
    c = Company.where(master:true).first_or_create!(name:@company_name)
    c.name = @company_name
    c.importer = true
    c.save!
    c
  end
  
  def prep_master_setup
    ms = MasterSetup.get
    ms.system_code = @system_code
    ms.order_enabled = true
    ms.vendor_management_enabled = true
    ms.save!
  end
  
  def prep_groups
    [
      ['ORDERACCEPT','Accept Order (Vendor)'],
      ['ORDERAPPROVE','Approve To Ship']
    ].each {|g| Group.use_system_group(g.first,name:g.last)}
  end
  
  def prep_user_templates
    prep_user_template_base_user
    prep_user_template_vendor_user
  end
  
  def prep_user_template_base_user
    t = UserTemplate.where(name:"Standard #{@short_name} User").first_or_create!
    h = {
      'permissions'=>[
        'order_view',
        'order_comment',
        'order_attach',
        'product_view',
        'product_comment',
        'product_attach',
        'vendor_view',
        'vendor_comment',
        'vendor_attach'
      ],
      'email_new_messages'=>true,
      'password_reset'=>true
    }
    t.template_json = h.to_json
    t.save!
    t
  end
  
  def prep_user_template_vendor_user
    t = UserTemplate.where(name:"Standard Vendor User").first_or_create!
    h = {
      'permissions'=>[
        'order_view',
        'order_comment',
        'order_attach',
        'product_view'
      ],
      'email_new_messages'=>true,
      'password_reset'=>true,
      'event_subscriptions'=>[
        {'event_type'=>'ORDER_CREATE','system_message'=>true},
        {'event_type'=>'ORDER_UNACCEPT','system_message'=>true},
        {'event_type'=>'ORDER_COMMENT_CREATE','system_message'=>true}
      ],
      'groups'=>['ORDERACCEPT'],
      'portal_mode'=>'vendor'
    }
    t.template_json = h.to_json
    t.save!
    t
  end
  
  def prep_search_table_configs
    [
      {
        page_uid:'vendor-product',
        name:'All Products',
        config: {"columns"=>["prodven_puid","prodven_pname"],"criteria"=>[],"sorts"=>[{"field":"prodven_puid","order":"A"}]}
      },
      {
        page_uid:'vendor-order',
        name:'All Orders',
        config: {
          columns:['ord_ord_num','ord_ord_date','ord_accepted_at',cdefs[:ord_approved_to_ship_date].model_field_uid.to_s],
          criteria:[],
          sorts:[
            {field:'ord_ord_num',order:'D'}
          ]
        }
      },
      {
        page_uid:'vendor-address',
        name: 'All Addresses',
        config: {
          columns:["add_name","add_full_address","add_shipping"],
          sorts:[{field:"add_name",order:"A"}]
        }
      },
      {
        page_uid:'chain-vp-order-panel',
        name: 'Needs To Be Accepted',
        config: {
          columns:["ord_ord_num","ord_ord_date","ord_window_end","ord_rule_state"],
          criteria:[{"field"=>"ord_accepted_at","operator"=>"null","val"=>""}],
          sorts:[{field:"ord_ord_num",order:"A"}]
        }
      },
      {
        page_uid:'chain-vp-order-panel',
        name: 'Approved To Ship',
        config: {
          columns:["ord_ord_num","ord_ord_date","ord_window_end","ord_rule_state"],
          criteria:[{"field"=>"ord_rule_state","operator"=>"eq","val"=>"Pass"}],
          sorts:[{field:"ord_ord_num",order:"A"}]
        }
      },
      {
        page_uid:'chain-vp-order-panel',
        name: 'All Orders',
        config: {
          columns:["ord_ord_num","ord_ord_date","ord_window_end","ord_accepted_at","ord_rule_state"],
          criteria:[],
          sorts:[{field:"ord_ord_num",order:"A"}]
        }
      },
      {
        page_uid:'chain-vp-order-panel',
        name: 'New Orders (14 Days)',
        config: {
          columns:["ord_ord_num","ord_ord_date","ord_window_end","ord_accepted_at","ord_rule_state"],
          criteria:[{field:'ord_ord_date',operator:'ada',val:'14'}],
          sorts:[{field:"ord_ord_num",order:"A"}]
        }
      }
    ].each do |h|
      stc = SearchTableConfig.where(page_uid:h[:page_uid],name:h[:name]).first_or_create!
      stc.config_hash = h[:config]
      stc.save!
    end
  end

  def prep_state_toggle_buttons
    stb = StateToggleButton.where(
      module_type:'Order',
      user_custom_definition_id:cdefs[:ord_approved_to_ship_by].id,
      date_custom_definition_id:cdefs[:ord_approved_to_ship_date].id,
      permission_group_system_codes: 'ORDERAPPROVE',
      activate_text:'Approve To Ship',
      deactivate_text:'Revoke Ship Approval'
    ).first_or_create!
    stb.deactivate_confirmation_text = 'Are you sure you want to revoke shipping approval?'
    stb.save!
  end
  
  def prep_business_validation_templates
    bvt = BusinessValidationTemplate.where(module_type:'Order',name:'Base Order').first_or_create!
    [
      {
        type:'ValidationRuleFieldFormat',
        name:'Vendor Must Accept Order',
        description:'Vendor must accept purchase order.',
        fail_state:'Fail',
        rule_attributes_json:'{"model_field_uid":"ord_accepted_at","regex":"[0-9]"}'
      },
      {
        type:'ValidationRuleFieldFormat',
        name:'Approve To Ship',
        description:"#{@short_name} must approve the order to ship.",
        fail_state:'Fail',
        rule_attributes_json:'{"model_field_uid":"'+cdefs[:ord_approved_to_ship_date].model_field_uid.to_s+'","regex":"[0-9]"}'
      }
    ].each do |bvr|
      bvt.business_validation_rules.where(bvr).first_or_create!
    end
    bvt.reload
    bvt.create_results! run_validation: true
    return true
  end
  
  def prep_attachment_types
    ['Purchase Order','Chain of Custody','PPQ','Specification','Other'].each do |n|
      AttachmentType.where(name:n).first_or_create!
    end
  end
  
  def cdefs 
    @cdefs ||= self.class.prep_custom_definitions [:ord_approved_to_ship_by,:ord_approved_to_ship_date]
    @cdefs
  end
end; end; end; end

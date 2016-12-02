require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module ConfigMigrations; module LL; class Booking
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  CDEF_FIELDS = [:ord_comp_docs_posted_by,:ord_comp_docs_posted_date,:ord_planned_handover_date]
  COMPLIANCE_DOCS_ACTIVATE_TEXT = "Set Compliance Docs Posted"
  def up
    cdefs = prep_custom_definitions
    populate_customer_order_number
    create_compliance_docs_posted_stb cdefs
    configure_vendor_permissions
    configure_master_permissions
    configure_vendor_business_rules
    set_shipment_validator_rules
    create_expeditors
    create_dhl
    change_planned_handover_permissions cdefs
    # add_variant_business_rule
    make_booking_read_only
    add_container_sizes
    configure_origin_ports
    update_vendor_user_template
  end

  def down
    cdefs = prep_custom_definitions
    reset_vendor_permissions
    destroy_compliance_docs_posted_stb cdefs
    clear_customer_order_number
  end
  
  def update_vendor_user_template
    ut = UserTemplate.where(name:'Basic Vendor').first_or_create!
    base_template = {
      disallow_password:false,
      email_format:"html",
      email_new_messages:true,
      homepage:nil,
      password_reset:true,
      portal_mode:"vendor",
      tariff_subscribed:false,
      event_subscriptions:[
        {event_type:"ORDER_CREATE",system_message:true},
        {event_type:"ORDER_UNACCEPT",system_message:true},
        {event_type:"ORDER_COMMENT_CREATE",system_message:true}
      ],
      groups:[
        "ORDERACCEPT"
      ],
      permissions:[
        "order_view",
        "order_comment",
        "order_edit",
        "order_attach",
        "shipment_view",
        "shipment_edit",
        "shipment_attach",
        "shipment_comment",
        "product_view"
      ]
    }
    ut.template_json = base_template.to_json
    ut.save!
  end

  def add_container_sizes
    fvr = FieldValidatorRule.where(model_field_uid:'con_container_size').first_or_create!(module_type:'Container')
    fvr.update_attributes(one_of:"20STD\n40STD\n40HQ\n45STD\n53\nLCL")
  end

  def make_booking_read_only
    ActiveRecord::Base.transaction do
      [:shp_booking_shipment_type,:shp_booking_mode,:shp_booking_received_date,
        :shp_booking_confirmed_date,:shp_booking_cutoff_date,:shp_booking_est_arrival_date,
        :shp_booking_est_departure_date,:shp_booking,:shp_booking_approved_date,
        :shp_booking_carrier,:shp_booking_vessel,:shp_booking_cargo_ready_date,
        :shp_booking_first_port_receipt_id,:shp_booking_requested_equipment
      ].each do |uid|
        fvr = FieldValidatorRule.where(model_field_uid:uid).first_or_create!(module_type:'Shipment')
        next if fvr.read_only?
        fvr.read_only = true
        fvr.save!
      end
    end
  end

  def add_variant_business_rule
    bvt = BusinessValidationTemplate.where(module_type:'Order').first
    raise "template not found" unless bvt
    bvr = bvt.business_validation_rules.where(type:'ValidationRuleOrderLineFieldFormat',name:'Vendor Variant Selection').first_or_create!
    bvr.search_criterions.where(model_field_uid:'ordln_has_variants',operator:'notnull').first_or_create!
    rule_attributes_hash = {
      "ordln_var_db_id"=>{"regex"=>"[0-9]"}
    }
    bvr.update_attributes(
      description:"All order lines with variants available must have a variant selected.",
      fail_state: 'Fail',
      rule_attributes_json: rule_attributes_hash.to_json,
      group_id: Group.use_system_group('PRODUCTCOMP').id
    )
  end

  def change_planned_handover_permissions cdefs
    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:ord_planned_handover_date].model_field_uid.to_s).first_or_create!(module_type:'Order')
    fvr.update_attributes(can_view_groups:"ALL",can_edit_groups:"ALL")
  end

  def create_expeditors
    exp = Company.where(system_code:'expeditors').first_or_create!(forwarder:true,name:'Expeditors')
    master = Company.where(master:true).first
    master.linked_companies << exp unless master.linked_companies.include?(exp)
    exp
  end
  def create_dhl
    dhl = Company.where(system_code:'DHL').first_or_create!(forwarder:true,name:'DHL')
    master = Company.where(master:true).first
    master.linked_companies << dhl unless master.linked_companies.include?(dhl)
    dhl
  end

  def set_shipment_validator_rules
    rules = {
      'shp_booking_mode'=>{one_of:"Air\nOcean\nTruck"},
      'shp_mode'=>{one_of:"Air\nOcean\nTruck"},
      'shp_booking_shipment_type'=>{one_of:"CY\nCFS\nAir"},
      'shp_shipment_type'=>{one_of:"CY\nCFS\nAir"}
    }
    rules.each do |uid,attrs|
      fvr = FieldValidatorRule.where(model_field_uid:uid).first_or_create!(module_type:'Shipment')
      fvr.update_attributes(attrs)
    end
  end

  def prep_custom_definitions
    self.class.prep_custom_definitions CDEF_FIELDS
  end

  def configure_vendor_business_rules
    u = User.integration
    Company.where(vendor:true).each do |v|
      next if v.show_business_rules?
      v.show_business_rules = true
      v.save!
      v.create_snapshot(u,nil,"Configure vendor business rules migration.")
    end
  end

  def populate_customer_order_number
    ActiveRecord::Base.connection.execute('UPDATE orders SET customer_order_number = order_number WHERE closed_at is null')
    u = User.integration
    Order.includes(:order_lines=>:product).where(closed_at:nil).find_each(batch_size:500) do |o|
      o.create_snapshot(u,nil,"Populate customer order number migration")
    end
  end

  def clear_customer_order_number
    ActiveRecord::Base.connection.execute('UPDATE orders SET customer_order_number = null')
  end


  def configure_vendor_permissions
    User.joins(:company).where('companies.vendor = 1').update_all(
      shipment_view:true,
      shipment_edit:true,
      shipment_comment:true,
      shipment_attach:true,
      order_view:true,
      order_edit:true,
      order_comment:true,
      order_attach:true,
      product_view:true
    )
  end

  def configure_master_permissions
    Company.find_by_master(true).users.update_all(
      shipment_view:true,
      shipment_comment:true,
      shipment_attach:true
    )
  end

  def reset_vendor_permissions
    User.joins(:company).where('companies.vendor = 1').update_all(
      shipment_view:false,
      shipment_edit:false,
      shipment_comment:false,
      shipment_attach:false
    )
  end

  def create_compliance_docs_posted_stb cdefs
    StateToggleButton.where(
      module_type:'Order',
      user_custom_definition_id:cdefs[:ord_comp_docs_posted_by].id,
      date_custom_definition_id:cdefs[:ord_comp_docs_posted_date].id,
      permission_group_system_codes:"ROPRODCOMP\nORDERACCEPT",
      activate_text:COMPLIANCE_DOCS_ACTIVATE_TEXT,
      deactivate_text:"Remove Compliance Docs Posted",
      deactivate_confirmation_text:"Are you sure you want to remove the compliance docs posted date? This will reset the KPI value."
    ).first_or_create!
  end

  def destroy_compliance_docs_posted_stb cdefs
    StateToggleButton.where(activate_text:COMPLIANCE_DOCS_ACTIVATE_TEXT).destroy_all
  end
  
  def configure_origin_ports
    ports = [["TRALI","ALIAGA"],
["CLARI","ARICA"],
["THBKK","BANGKOK"],
["COBAQ","BARRANQUILLA"],
["BRBEL","BELEM"],
["DEBRV","BREMERHAVEN"],
["ARBUE","BUENOS AIRES"],
["KRPUS","BUSAN"],
["PECLL","CALLAO"],
["COCTG","CARTAGENA"],
["INMAA","CHENNAI (EX MADRAS)"],
["CNCWN","CHIWAN"],
["CNDLC","DALIAN"],
["TRDNZ","DENIZLI"],
["CNFOS","FOSHAN"],
["CNFOC","FUZHOU"],
["TRGEM","GEMLIK"],
["ITGOA","GENOA"],
["CNCAN","GUANGZHOU"],
["CNXSA","GUANGZHOU"],
["VNHPH","HAIPHONG"],
["VNSGN","HO CHI MINH CITY"],
["VNVIC","HO CHI MINH VICT"],
["HKHKG","HONG KONG"],
["CNHUA","HUANGPU"],
["BRIOA","ITAPOA"],
["TRIZM","IZMIR"],
["IDCGK","JAKARTA"],
["IDJKT","JAKARTA"],
["CNJIU","JIUJIANG"],
["CNJJG","JIUJIANG"],
["TWKHH","KAOHSIUNG"],
["ITSPE","LA SPEZIA"],
["THLCH","LAEM CHABANG"],
["PELIM","LIMA"],
["ITLIV","LIVORNO"],
["UYMVD","MONTEVIDEO"],
["INBOM","MUMBAI (EX BOMBAY)"],
["CNNKG","NANJING"],
["CNNSA","NANSHA"],
["BRNVT","NAVEGANTES"],
["INNSA","NHAVA SHEVA"],
["CNNGB","NINGBO"],
["BRPNG","PARANAGUA"],
["MYPKG","PORT KLANG"],
["CNTAO","QINGDAO"],
["BRSSZ","SANTOS"],
["IDSRG","SEMARANG"],
["CNSHA","SHANGHAI"],
["SGSIN","SINGAPORE"],
["BRSUA","SUAPE"],
["TWTXG","TAICHUNG"],
["BRVAL","VALENCA"],
["BRVLC","VILA DO CONDE"],
["BRVIC","VILA DO CONDE"],
["CNXMN","XIAMEN"],
["CNXGG","XINGANG"],
["CNYTN","YANTIAN"],
["CNZHE","ZHENJIANG"]]
    ports.each do |pdata|
      Port.where(unlocode:pdata[0]).first_or_create!(name:"#{pdata[1]} (#{pdata[0]})")
    end
    Port.where('unlocode is not null').update_all(active_origin: true)
  end
end; end; end

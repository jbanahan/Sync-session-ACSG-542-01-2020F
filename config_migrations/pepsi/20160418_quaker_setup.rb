require 'open_chain/custom_handler/pepsi/pepsi_custom_definition_support'
module ConfigMigrations; module Pepsi; class QuakerSetup
  include OpenChain::CustomHandler::Pepsi::PepsiCustomDefinitionSupport

  NEW_FIELDS = [
    :class_audit,
    :class_ior,
    :class_fta_start,
    :class_fta_end,
    :class_fta_notes,
    :class_tariff_shift,
    :class_val_content,
    :class_add_cvd,
    :class_fta_criteria,
    :prod_shipper_name,
    :prod_us_broker,
    :prod_us_alt_broker,
    :prod_prod_code,
    :prod_alt_prod_code,
    :prod_coo,
    :prod_tcsa,
    :prod_recod,
    :prod_first_sale,
    :prod_related,
    :prod_fda_pn,
    :prod_fda_uom_1,
    :prod_fda_uom_2,
    :prod_fda_fce,
    :prod_fda_sid,
    :prod_fda_dims,
    :prod_oga_1,
    :prod_oga_2,
    :prod_oga_3,
    :prod_prog_code,
    :prod_proc_code,
    :prod_indented_use,
    :prod_trade_name,
    :prod_cbp_mid,
    :prod_fda_mid,
    :prod_fda_desc
  ]

  def up
    et = create_new_entity_type
    create_new_fields et
    register_existing_fields_for_entity_type et
    update_existing_validate_buttons
    update_existing_validation_definitions
    user_cd, date_cd = create_new_validation_definitions
    create_quaker_system_group
    create_quaker_validate_button user_cd, date_cd
    update_custom_definition_ranks
    create_business_validation_template
  end

  def down
    destroy_quaker_validate_button
    destroy_quaker_system_group
    destroy_new_validation_definitions
    roll_back_existing_validation_definitions
    destroy_existing_validate_button_new_criteria
    destroy_new_fields
    destroy_new_entity_type
  end

  def update_custom_definition_ranks
    defs = OpenChain::CustomHandler::Pepsi::PepsiCustomDefinitionSupport::CUSTOM_DEFINITION_INSTRUCTIONS
    self.class.prep_custom_definitions(defs.keys).each do |k,cd|
      next if defs[k][:rank].blank?
      cd.update_attributes(rank:defs[k][:rank])
    end
  end


  def create_business_validation_template
    defs = self.class.prep_custom_definitions([:prod_fss_code,:prod_base_customs_description])
    ActiveRecord::Base.transaction do
      bvt = BusinessValidationTemplate.create!(module_type:'Product',name:'Non-Quaker Validations',description:'Additional rules for non-quaker products.')
      bvt.search_criterions.create!(model_field_uid:'prod_ent_type',operator:'nq',value:'Quaker')
      [
        ["FSS Code",defs[:prod_fss_code].model_field_uid],
        ["Base Customs Description",defs[:prod_base_customs_description].model_field_uid],
        ["Division Name",'prod_div_name']
      ].each do |r|
        bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat',name:"#{r[0]} Required",description:"#{r[0]} is required.",
          rule_attributes_json:"{\"model_field_uid\":\"#{r[1]}\",\"regex\":\"\\\\w\"}"
        )
      end
      bvt.create_results! true
    end
  end
  def create_new_entity_type
    EntityType.where(module_type:'Product',name:'Quaker').first_or_create!
  end

  def destroy_new_entity_type
    EntityType.where(module_type:'Product',name:'Quaker').destroy_all
  end

  def create_new_fields entity_type
    cdefs = self.class.prep_custom_definitions(NEW_FIELDS)
    cdefs.values.each do |cd|
      EntityTypeField.where(model_field_uid:cd.model_field_uid,entity_type_id:entity_type.id).first_or_create!
    end
    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:class_fta_criteria].model_field_uid).first_or_create!
    fvr.one_of = "A\nB\nC\nD\nE\nF"
    fvr.save!

    coo_fvr = FieldValidatorRule.where(model_field_uid:cdefs[:prod_coo].model_field_uid).first_or_create!
    coo_fvr.one_of = ["AD","AE","AF","AG","AI","AL","AM","AO","AQ","AR","AS","AT","AU","AW","AX","AZ",
      "BA","BB","BD","BE","BF","BG","BH","BI","BJ","BL","BM","BN","BO","BQ","BR","BS","BT","BV","BW","BY","BZ",
      "CC","CD","CF","CG","CH","CI","CK","CL","CM","CN","CO","CR","CU","CV","CW","CX","CY","CZ","DE","DJ","DK","DM","DO","DZ",
      "EC","EE","EG","EH","ER","ES","ET","FI","FJ","FK","FM","FO","FR","GA","GB","GD","GE","GF","GG","GH","GI","GL","GM","GN",
      "GP","GQ","GR","GS","GT","GU","GW","GY","HK","HM","HN","HR","HT","HU","ID","IE","IL","IM","IN","IO","IQ","IR","IS","IT",
      "JE","JM","JO","JP","KE","KG","KH","KI","KM","KN","KP","KR","KW","KY","KZ","LA","LB","LC","LI","LK","LR","LS","LT","LU",
      "LV","LY","MA","MC","MD","ME","MF","MG","MH","MK","ML","MM","MN","MO","MP","MQ","MR","MS","MT","MU","MV","MW","MX","MY",
      "MZ","NA","NC","NE","NF","NG","NI","NL","NO","NP","NR","NU","NZ","OM","PA","PE","PF","PG","PH","PK","PL","PM","PN","PR",
      "PS","PT","PW","PY","QA","RE","RO","RS","RU","RW","SA","SB","SC","SD","SE","SG","SH","SI","SJ","SK","SL","SM","SN","SO",
      "SR","ST","SV","SX","SY","SZ","TC","TD","TF","TG","TH","TJ","TK","TL","TM","TN","TO","TR","TT","TV","TW","TZ","UA","UG",
      "UM","US","UY","UZ","VA","VC","VE","VG","VI","VN","VU","WF","WS","XA","XB","XC","XM","XN","XO","XP","XQ","XS","XT","XW",
      "XY","YE","YT","ZA","ZM","ZW"].join("\n")
    coo_fvr.save!
  end

  def register_existing_fields_for_entity_type entity_type
    [:prod_uid,:prod_name].each do |mfuid|
      EntityTypeField.where(model_field_uid:mfuid,entity_type_id:entity_type.id).first_or_create!
    end
  end

  def destroy_new_fields
    et = EntityType.where(module_type:'Product',name:'Quaker').first
    EntityTypeField.where(entity_type_id:et.id).destroy_all if et
    self.class.prep_custom_definitions(NEW_FIELDS).each do |cd|
      cd.destroy
    end
  end

  def update_existing_validate_buttons
    StateToggleButton.where(module_type:'Product').each do |stb|
      stb.search_criterions.where(model_field_uid:'prod_ent_type',operator:'nq',value:'Quaker').first_or_create!
      stb.update_attributes(activate_text:"#{stb.activate_text} (PWF)",deactivate_text:"#{stb.deactivate_text} (PWF)")
    end
  end
  def destroy_existing_validate_button_new_criteria
    SearchCriterion.where('state_toggle_button_id is not null').where(value:'Quaker').destroy_all
  end

  def update_existing_validation_definitions
    CustomDefinition.where(module_type:'Product').where("label like 'validated%'").each do |cd|
      cd.update_attributes(label:"#{cd.label} (PWF)")
    end
  end
  def roll_back_existing_validation_definitions
    CustomDefinition.where(module_type:'Product').where("label like 'validated%PWF)'").each do |cd|
      cd.update_attributes(label:cd.label.gsub(/ \(PWF\)/,''))
    end
  end

  def create_new_validation_definitions
    cdefs = self.class.prep_custom_definitions([:prod_quaker_validated_by, :prod_quaker_validated_date])
    return [cdefs[:prod_quaker_validated_by], cdefs[:prod_quaker_validated_date]]
  end
  def destroy_new_validation_definitions
    self.class.prep_custom_definitions([:prod_quaker_validated_by, :prod_quaker_validated_date]).values.each do |cd|
      cd.destroy
    end
  end

  def create_quaker_system_group
    Group.where(system_code:'QUAKER-VALIDATORS').first_or_create!(name:'Quaker Validators')
  end
  def destroy_quaker_system_group
    Group.where(system_code:'QUAKER-VALIDATORS').destroy
  end

  def create_quaker_validate_button user_cd, date_cd
    stb = StateToggleButton.create!(module_type:'Product',
      user_custom_definition_id:user_cd.id,date_custom_definition_id:date_cd.id,
      activate_text:'Validate (Quaker)',deactivate_text:'Revoke Validation (Quaker)',
      deactivate_confirmation_text:'Are you sure you want to revoke this validation?',
      permission_group_system_codes:'QUAKER-VALIDATORS'
    )
    stb.search_criterions.create!(model_field_uid:'prod_ent_type',operator:'eq',value:'Quaker')
  end
  def destroy_quaker_validate_button
    StateToggleButton.where(module_type:'Product').where("activate_text like '%quaker%'").destroy_all
  end

end; end; end

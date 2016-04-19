require 'open_chain/custom_handler/pepsi/pepsi_custom_definition_support'
module ConfigMigrations; module Pepsi; class QuakerSetup
  include OpenChain::CustomHandler::Pepsi::PepsiCustomDefinitionSupport

  NEW_FIELDS = [
    :class_ior,
    :class_fta_start,
    :class_fta_end,
    :class_fta_notes,
    :class_tariff_shift,
    :class_val_content,
    :class_add_cvd,
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
    update_existing_validate_buttons
    update_existing_validation_definitions
    user_cd, date_cd = create_new_validation_definitions
    create_quaker_system_group
    create_quaker_validate_button user_cd, date_cd
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
    stb = StateToggleButton.create!(module_type:'Product',user_custom_definition_id:user_cd.id,date_custom_definition_id:date_cd.id,activate_text:'Validate (Quaker)',deactivate_text:'Revoke Validation (Quaker)',deactivate_confirmation_text:'Are you sure you want to revoke this validation?')
    stb.search_criterions.create!(model_field_uid:'prod_ent_type',operator:'eq',value:'Quaker')
  end
  def destroy_quaker_validate_button
    StateToggleButton.where(module_type:'Product').where("activate_text like '%quaker%'").destroy_all
  end

end; end; end

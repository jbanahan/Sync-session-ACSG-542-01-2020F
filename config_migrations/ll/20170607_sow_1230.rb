require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module ConfigMigrations; module LL; class Sow1230
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  CDEF_FIELDS = [:ordln_inland_freight_amount,:ordln_inland_freight_vendor_number]
  def prep_custom_definitions
    self.class.prep_custom_definitions CDEF_FIELDS
  end

  def up
    cdefs = prep_custom_definitions
    make_field_validations cdefs
  end

  def down
    cdefs = prep_custom_definitions
    remove_field_validations cdefs
  end

  def make_field_validations cdefs
    [:ordln_inland_freight_amount, :ordln_inland_freight_vendor_number].each do |k|
      cd = cdefs[k]
      fvr = FieldValidatorRule.where(model_field_uid:cd.model_field_uid.to_s, module_type:'OrderLine').first_or_create!
      fvr.update_attributes(can_view_groups:"ADMIN")
    end
  end

  def remove_field_validations cdefs
    cdefs.each do |k,v|
      FieldValidatorRule.find_by_model_field_uid(v.model_field_uid.to_s).destroy
    end
  end

end; end; end
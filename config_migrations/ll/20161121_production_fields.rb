require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module ConfigMigrations; module LL; class ProductionFields
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  CDEF_FIELDS = [:ord_internal_production_articles, :ord_internal_production_orders]
  def prep_custom_definitions
    self.class.prep_custom_definitions CDEF_FIELDS
  end

  def up
    cdefs = prep_custom_definitions
    make_groups
    make_field_validations cdefs
  end

  def down
    cdefs = prep_custom_definitions
    remove_field_validations cdefs
    remove_groups
  end
  def remove_field_validations cdefs
    cdefs.each do |k, v|
      FieldValidatorRule.find_by_model_field_uid(v.model_field_uid.to_s).destroy
    end
  end
  def make_field_validations cdefs
    h = {ord_internal_production_articles:{
        g:'INTERNALPROD'
      },
      ord_internal_production_orders:{
        g:'INTERNALPROD'
      }
    }
    h.each do |k, v|
      cd = cdefs[k]
      fvr = FieldValidatorRule.where(model_field_uid:cd.model_field_uid.to_s, module_type:'ProductVendorAssignment').first_or_create!
      fvr.update_attributes(can_view_groups:"ALL\n#{v[:g]}", can_edit_groups:v[:g])
    end
  end

  def make_groups
    Group.use_system_group 'INTERNALPROD', name: 'Internal Production', create: true
  end

  def remove_groups
    Group.where(system_code:'INTERNALPROD').destroy_all
  end
end; end; end

require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
module ConfigMigrations; module LL; class PatentCarb
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  CDEF_FIELDS = [:prodven_carb, :prodven_patent]
  def prep_custom_definitions
    self.class.prep_custom_definitions CDEF_FIELDS
  end

  def up
    cdefs = prep_custom_definitions
    make_groups
    make_field_validations cdefs
    make_search_table_config cdefs
  end

  def down
    cdefs = prep_custom_definitions
    remove_search_table_config cdefs
    remove_field_validations cdefs
    remove_groups
  end

  def make_search_table_config cdefs
    stc = SearchTableConfig.where(page_uid:'vendor-product', name:'CARB/Patent').first_or_create!
    stc.config_hash = {
      columns:['prodven_puid', 'prodven_name', cdefs[:prodven_carb].model_field_uid, cdefs[:prodven_patent].model_field_uid],
      sorts:[{field:'prodven_puid', order:'A'}]
    }
    stc.save!
  end
  def remove_search_table_config cdefs
    SearchTableConfig.where(page_uid:'vendor-product', name:'CARB/Patent').destroy
  end
  def remove_field_validations cdefs
    cdefs.each do |k, v|
      FieldValidatorRule.find_by_model_field_uid(v.model_field_uid.to_s).destroy
    end
  end
  def make_field_validations cdefs
    h = {prodven_carb:{
        g:'CARBASSIGN', o: [
          "A – COMPLIES WITH CA 93120 CARB PHASE 2",
          "B – CARB – NAF RESIN – CA 93120",
          "C – CARB – ULEF RESIN – CA 93120"
        ]
      },
      prodven_patent:{
        g:'PATENTASSIGN', o: [
          "J – SOLD UNDER LICENSE OF FLOORING INDUSTRIES, LTD.",
          "K – LOCKING SYSTEM PRODUCED UNDER LICENSE FROM VALINGE INNOVATION AB AN FLOORING INDUSTRIES"
        ]
      }
    }
    h.each do |k, v|
      cd = cdefs[k]
      fvr = FieldValidatorRule.where(model_field_uid:cd.model_field_uid.to_s, module_type:'ProductVendorAssignment').first_or_create!
      fvr.update_attributes(can_view_groups:"ALL\nORDERACCEPT\n#{v[:g]}", can_edit_groups:v[:g], one_of:v[:o].join("\n"))
    end
  end

  def make_groups
    Group.use_system_group 'PATENTASSIGN', name: 'Patent Assignment', create: true
    Group.use_system_group 'CARBASSIGN', name: 'CARB Assignment', create: true
  end

  def remove_groups
    Group.where(system_code:['PATENTASSIGN', 'CARBASSIGN']).destroy_all
  end
end; end; end

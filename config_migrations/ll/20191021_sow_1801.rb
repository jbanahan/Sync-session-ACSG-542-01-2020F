require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
module ConfigMigrations; module LL; class SOW1801
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  DEFS = [:prodven_risk]

  def defs
    @defs ||= self.class.prep_custom_definitions(DEFS)
  end

  def up
    change_master_address
    change_one_of_fvr
    change_search_setup
    change_custom_values
  end

  def change_master_address
    Company.where(master: true).first.
        addresses.where(["line_1 LIKE ?", "%deere%"]).
        update_all(
            line_1: "4901 BAKERS MILL LANE",
            city: "RICHMOND",
            state: "VA",
            postal_code: "23230-2431",
            phone_number: "(804)463-2000"
        )
  end

  def change_one_of_fvr
    cd = defs[:prodven_risk]
    fvr = FieldValidatorRule.where(model_field_uid: cd.model_field_uid, module_type: cd.module_type).first
    fvr.one_of.gsub("Grandfathered", "Extinct")
    fvr.save!
  end

  def change_search_setup
    stc = SearchTableConfig.where(page_uid: "vendor-product", name: "Risk: Grandfathered").first
    stc.name = "Risk: Extinct"
    stc.config_json = stc.config_json.gsub("Grandfathered", "Extinct")
    stc.save!
  end

  def change_custom_values
    user = User.integration
    cd = defs[:prodven_risk]
    CustomValue.where(customizable_type: cd.module_type, string_value: "Grandfathered").find_each do |v|
      v.update!(string_value: 'Extinct')
      v.customizable.create_snapshot(user, nil, "SOW 1801: Modify 'Grandfathered' risk values to 'Extinct'")
    end
  end
end; end; end

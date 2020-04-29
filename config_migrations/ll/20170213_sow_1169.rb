require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
module ConfigMigrations; module LL; class SOW1169
  def up
    add_new_risk_level
    add_new_search
  end
  def down
    remove_new_search
    remove_new_risk_level
  end

  def remove_new_risk_level
    cdefs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions([:prodven_risk])
    cd = cdefs[:prodven_risk]
    fvr = FieldValidatorRule.find_by_model_field_uid(cd.model_field_uid)
    fvr.one_of = fvr.one_of.gsub("Domestic Low Auto-Flow\n", '')
    fvr.save!
  end
  def add_new_risk_level
    cdefs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions([:prodven_risk])
    cd = cdefs[:prodven_risk]
    fvr = FieldValidatorRule.find_by_model_field_uid(cd.model_field_uid)
    risks = fvr.one_of.lines.map(&:strip)
    risks.insert(1, 'Domestic Low Auto-Flow')
    fvr.one_of = risks.join("\n")
    fvr.save!
  end

  def add_new_search
    cdefs = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions([:prodven_risk, :prod_merch_cat_desc])
    ch = make_prodven_risk('Risk: Domestic Low Auto-Flow', 'Domestic Low Auto-Flow', cdefs)
    stc = SearchTableConfig.where(page_uid:ch[:page_uid], name:ch[:name]).first
    stc = SearchTableConfig.new(page_uid:ch[:page_uid], name:ch[:name]) unless stc
    stc.config_hash = ch[:config_hash]
    stc.save!
  end

  def remove_new_search
    OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions([:prodven_risk, :prod_merch_cat_desc])
    ch = make_prodven_risk('Risk: Domestic Low Auto-Flow', 'Domestic Low Auto-Flow', cdefs)
    SearchTableConfig.where(page_uid:ch[:page_uid], name:ch[:name]).destroy_all
  end

  def make_prodven_risk label, level, defs
    pvr_uid = defs[:prodven_risk].model_field_uid.to_s
    r = {
      page_uid: 'vendor-product',
      name: label,
      config_hash: {
        columns: ['prodven_puid', 'prodven_pname', "#{defs[:prod_merch_cat_desc].model_field_uid}_product_vendor_assignment", pvr_uid],
        criteria: [
        ],
        sorts: [
          {field:'prodven_puid', order:'A'}
        ]
      },
    }
    r[:config_hash][:criteria] << {field:pvr_uid, operator:'eq', val:level} unless level.nil?
    r
  end
end; end; end

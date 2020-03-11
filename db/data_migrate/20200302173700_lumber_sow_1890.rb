class LumberSow1890 < ActiveRecord::Migration

  def up
    if MasterSetup.get.custom_feature?("Lumber Liquidators")
      add_business_validation_rules
    end
  end

  def down
    if MasterSetup.get.custom_feature?("Lumber Liquidators")
      drop_business_validation_rules
    end
  end

  def add_business_validation_rules
    bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'Canada Entry Validations', description: 'Rules for Canadian entries').first_or_create!
    bvt.search_criterions.where(operator: "eq", model_field_uid:"ent_importer_tax_id", value:"808543466RM0001").first_or_create!
    bvt.search_criterions.where(operator: "eq", model_field_uid:"ent_cntry_iso", value:"CA").first_or_create!
    bvt.update_attributes!(
        private: false,
        disabled: false
    )

    bvr = bvt.business_validation_rules.where(type:'OpenChain::CustomHandler::LumberLiquidators::LumberValidationRuleCanadaEntryNafta', name: 'NAFTA-flagged Products', description: "If any of the products on this entry are NAFTA-flagged, the entry is set to review status.").first_or_create!
    bvr.search_criterions.where(operator: "notnull", model_field_uid:"ent_across_sent_date", value:"").first_or_create!
    bvr.update_attributes!(
        fail_state: "Review",
        disabled: false
    )
  end

  def drop_business_validation_rules
    bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'Canada Entry Validations').first
    bvt.destroy if bvt
  end

end
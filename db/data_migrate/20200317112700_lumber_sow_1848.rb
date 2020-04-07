class LumberSow1848 < ActiveRecord::Migration

  def up
    if MasterSetup.get.custom_feature?("WWW")
      add_business_validation_rules
    end
  end

  def down
    if MasterSetup.get.custom_feature?("WWW")
      drop_business_validation_rules
    end
  end

  def add_business_validation_rules
    bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'No SPI Claimed', description: 'Entries with unclaimed SPI').first_or_create!
    bvt.search_criterions.where(operator: "ama", model_field_uid:"ent_file_logged_date", value:"1").first_or_create!
    bvt.search_criterions.where(operator: "ada", model_field_uid:"ent_one_usg_date", value:"14", include_empty:true).first_or_create!
    bvt.update_attributes!(
        private: false,
        disabled: false
    )

    bvr = bvt.business_validation_rules.where(type:'OpenChain::CustomHandler::Vandegrift::SpiClaimEntryValidationRule', name: 'No SPI Claimed', description: "If no SPI has been claimed and the country of export/origin combo has available SPI options, the entry is set to review status.").first_or_create!
    bvr.search_criterions.where(operator: "notnull", model_field_uid:"ent_export_country_codes", value:"").first_or_create!
    bvr.search_criterions.where(operator: "notnull", model_field_uid:"ent_origin_country_codes", value:"").first_or_create!
    bvr.update_attributes!(
        fail_state: "Review",
        disabled: false
    )
  end

  def drop_business_validation_rules
    bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'No SPI Claimed').first
    bvt.destroy if bvt
  end

end
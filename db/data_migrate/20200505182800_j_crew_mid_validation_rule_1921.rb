class JCrewMidValidationRule1921 < ActiveRecord::Migration
  def up
    if MasterSetup.get.custom_feature?("WWW")
      # This template exists in production already, but not in test environment(s).
      bvt = BusinessValidationTemplate.where(module_type: "Entry", name: "J Crew", description: "J Crew entry rules").first_or_create!
      if bvt.search_criterions.length == 0
        bvt.search_criterions.create!(operator: "in", model_field_uid: "ent_cust_num", value: "JCREW\nJ0000")
        bvt.search_criterions.create!(operator: "gteq", model_field_uid: "ent_file_logged_date", value: "2016-01-16")
        bvt.update_attributes!(
            private: true,
            disabled: false
        )
      end

      bvr = bvt.business_validation_rules.where(type:"ValidationRuleEntryMidMatchesMidList", name: "Entry MIDs Must Match Uploaded MIDs", description: "Entry MIDs Must Match Uploaded MIDs").first_or_create!
      bvr.update_attributes!(
          fail_state: "Fail",
          rule_attributes_json: "{\"importer\": \"JCREW\"}",
          disabled: false
      )
    end
  end

  def down
    if MasterSetup.get.custom_feature?("WWW")
      bvt = BusinessValidationTemplate.where(module_type: "Entry", name: "J Crew").first
      if bvt
        bvr = bvt.business_validation_rules.where(type:"ValidationRuleEntryMidMatchesMidList", name: "Entry MIDs Must Match Uploaded MIDs").first
        bvr.destroy if bvr
      end
    end
  end

end

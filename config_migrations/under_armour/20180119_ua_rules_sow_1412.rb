module ConfigMigrations; module UnderArmour; class UaRulesSow1412

  def up
    add_business_validation_rules
  end

  def down
    drop_business_validation_rules
  end

  def add_business_validation_rules
    ActiveRecord::Base.transaction do
      bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'Under Armour Canada').first_or_create!
      # Remove the existing file logged date criterion, which uses a static date value.
      bvt.search_criterions.where(model_field_uid:'ent_file_logged_date', value:'2015-07-23', operator:'gteq').delete_all
      # Re-add the file logged date criterion using a rolling date.
      bvt.search_criterions.create!(operator:'ama', model_field_uid:'ent_file_logged_date', value:'12')

      override_group = Group.where(system_code: 'canada-business-rules-override').first

      bvr1 = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name: 'First DO Date').first_or_create!
      bvr1.update_attributes!(
          description: "Under Armour Entries require a First DO Date which is entered in Fenix as the activity 'DO GIVEN OUT'.",
          fail_state: "Fail",
          rule_attributes_json: {
              "model_field_uid"=>"ent_first_do_issued_date",
              "regex"=>".+"
          }.to_json,
          group_id: override_group.id,
          disabled: false
      )

      bvr2 = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name: 'Country of Origin Requires Certificates').first_or_create!
      bvr2.update_attributes!(
          description: "The Entry contains a Country of Origin code that requires certificates. Verify Certificates are included. Countries affected are HN, IL, JO, MX, PE, US and CA.",
          fail_state: "Review",
          rule_attributes_json: {
              "model_field_uid"=>"ent_origin_country_codes",
              "regex"=>"^(?!.*(HN|IL|JO|MX|PE|US|CA)).*$"
          }.to_json,
          group_id: override_group.id,
          disabled: false
      )

      bvr3 = bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name: 'Country of Origin Requires Permits').first_or_create!
      bvr3.update_attributes!(
          description: "The Entry contains a Country of Origin code that requires permits. Verify permits are included. Countries affected are HN and MX.",
          fail_state: "Review",
          rule_attributes_json: {
              "model_field_uid"=>"ent_origin_country_codes",
              "regex"=>"^(?!.*(HN|MX)).*$"
          }.to_json,
          group_id: override_group.id,
          disabled: false
      )
    end
  end

  def drop_business_validation_rules
    ActiveRecord::Base.transaction do
      bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'Under Armour Canada').first
      if bvt
        bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name: 'First DO Date').delete_all
        bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name: 'Country of Origin Requires Certificates').delete_all
        bvt.business_validation_rules.where(type:'ValidationRuleFieldFormat', name: 'Country of Origin Requires Permits').delete_all
        bvt.search_criterions.where(operator:'ama', model_field_uid:'ent_file_logged_date', value:'12').delete_all
        bvt.search_criterions.create!(model_field_uid:'ent_file_logged_date', value:'2015-07-23', operator:'gteq')
      end
    end
  end

end; end; end
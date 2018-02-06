module ConfigMigrations; module Burlington; class BurlingtonRulesSow1406

  def up
    add_business_validation_rules
  end

  def down
    drop_business_validation_rules
  end

  def add_business_validation_rules
    ActiveRecord::Base.transaction do
      bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'Burlington Entry Rules').first_or_create! disabled: true

      bvr = bvt.business_validation_rules.where(type:'ValidationRuleEntryDoesNotSharePos', name: 'PO Numbers Not Shared').first_or_create!
      bvr.update_attributes!(
          description: "PO Numbers cannot be shared between multiple entries.",
          fail_state: "Fail",
          disabled: false
      )
    end
  end

  def drop_business_validation_rules
    ActiveRecord::Base.transaction do
      bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'Burlington Entry Rules').first
      if bvt
        bvt.business_validation_rules.where(type:'ValidationRuleEntryDoesNotSharePos', name: 'PO Numbers Not Shared').delete_all
      end
    end
  end

end; end; end
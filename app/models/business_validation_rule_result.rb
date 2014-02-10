class BusinessValidationRuleResult < ActiveRecord::Base
  belongs_to :business_validation_result, touch: true
  belongs_to :business_validation_rule, inverse_of: :business_validation_rule_results
  belongs_to :overridden_by, class_name:'User'
  attr_accessible :message, :note, :overridden_at, :state


  def run_validation obj
    return if self.overridden_at
    run_validation = true
    self.business_validation_rule.search_criterions.each do |sc|
      run_validation = sc.test?(obj)
      break unless run_validation
    end
    if !run_validation
      self.message = nil
      self.state = 'Skipped'
      return
    end
    self.message = self.business_validation_rule.run_validation(obj)
    if self.message.nil?
      self.state = 'Pass'
    elsif self.business_validation_rule.fail_state.blank?
      self.state = 'Fail'
    else
      self.state = self.business_validation_rule.fail_state
    end
  end

  def override override_user
    self.overridden_by = override_user
    self.overridden_at = Time.now
  end
end

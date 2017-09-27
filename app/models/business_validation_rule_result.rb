class BusinessValidationRuleResult < ActiveRecord::Base
  belongs_to :business_validation_result, touch: true
  belongs_to :business_validation_rule, inverse_of: :business_validation_rule_results
  belongs_to :overridden_by, class_name:'User'
  attr_accessible :message, :note, :overridden_at, :overridden_by, :state

  after_destroy { |rr| delete_parent_bvre rr }

  def can_view? user
    user.view_business_validation_rule_results?
  end

  def can_edit? user
    if business_validation_rule.group
      user.admin? || (user.in_group? business_validation_rule.group)
    else
      user.edit_business_validation_rule_results?
    end
  end

  # updates the state of the object based on the validation and returns true if it changed
  def run_validation obj
    original_value = self.state
    # validation rule can be nil if it's in the process of getting deleted (which can take time since there's
    # potentially hundreds of thousands of rule results).
    return false if self.overridden_at || self.business_validation_rule.nil? || self.business_validation_rule.delete_pending?
    if self.business_validation_rule.should_skip? obj
      self.message = nil
      self.state = 'Skipped'
      return self.state != original_value
    end
    self.message = self.business_validation_rule.run_validation(obj)
    if self.message.nil?
      self.state = 'Pass'
    else
      self.state = self.business_validation_rule.fail_state.presence || 'Fail'
    end
    return self.state != original_value
  end

  def override override_user
    self.overridden_by = override_user
    self.overridden_at = Time.now
  end

  def cancel_override
    self.overridden_by = nil
    self.overridden_at = nil
    self.note = nil
    save!
  end

  def self.destroy_batch ids
    BusinessValidationRuleResult.where(id: ids).find_each do |rule_result|
      rule_result.destroy
    end
  end

  private

  def delete_parent_bvre rr
    bvre_id = rr.business_validation_result_id
    total = BusinessValidationRuleResult.where(business_validation_result_id: bvre_id).count
    if total.zero?
      # Have to look this up from DB to prevent a vicious in-memory, recursive after_delete callback loop
      validation_result = BusinessValidationResult.where(id: bvre_id).first
      validation_result.destroy if validation_result
    end
  end

end

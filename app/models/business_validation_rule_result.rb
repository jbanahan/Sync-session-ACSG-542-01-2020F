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

  def run_validation obj
    return if self.overridden_at
    if self.business_validation_rule.should_skip? obj
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

  def cancel_override
    self.overridden_by = nil
    self.overridden_at = nil
    self.note = nil
    save!
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

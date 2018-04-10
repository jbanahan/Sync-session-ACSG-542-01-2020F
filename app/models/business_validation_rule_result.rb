# == Schema Information
#
# Table name: business_validation_rule_results
#
#  business_validation_result_id :integer
#  business_validation_rule_id   :integer
#  created_at                    :datetime         not null
#  id                            :integer          not null, primary key
#  message                       :text
#  note                          :text
#  overridden_at                 :datetime
#  overridden_by_id              :integer
#  state                         :string(255)
#  updated_at                    :datetime         not null
#
# Indexes
#
#  business_validation_result                                  (business_validation_result_id)
#  business_validation_rule                                    (business_validation_rule_id)
#  index_business_validation_rule_results_on_overridden_by_id  (overridden_by_id)
#

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
    original_message = self.message
    original_value = self.state
    # validation rule can be nil if it's in the process of getting deleted (which can take time since there's
    # potentially hundreds of thousands of rule results).
    return false if self.overridden_at || self.business_validation_rule.nil? || self.business_validation_rule.delete_pending?
    if self.business_validation_rule.should_skip? obj
      self.message = nil
      self.state = 'Skipped'
      return self.state != original_value
    end
    messages = self.business_validation_rule.run_validation(obj)
    # Use blank because we do allow arrays to be returned, so we consider any value 
    # of blank that is returned (blank strings, blank arrays) to be an indication of passing
    if !messages.blank?
      # Allow for returning multiple messages directly from the run_validation method
      self.message = Array.wrap(messages).map(&:to_s).join("\n")
    else
      self.message = nil
    end

    if self.message.nil?
      self.state = 'Pass'
    else
      self.state = self.business_validation_rule.fail_state.presence || 'Fail'
    end
    return (self.state != original_value) || (self.message != original_message)
  end

  def run_validation_with_state_tracking obj
    old_state = self.state
    changed = run_validation(obj)
    new_state = self.state

    {id: self.id, changed: changed, new_state: new_state, old_state: old_state}
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

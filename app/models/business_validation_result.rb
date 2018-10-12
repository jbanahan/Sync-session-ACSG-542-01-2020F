# == Schema Information
#
# Table name: business_validation_results
#
#  business_validation_template_id :integer
#  created_at                      :datetime         not null
#  id                              :integer          not null, primary key
#  state                           :string(255)
#  updated_at                      :datetime         not null
#  validatable_id                  :integer
#  validatable_type                :string(255)
#
# Indexes
#
#  business_validation_template  (business_validation_template_id)
#  validatable                   (validatable_id,validatable_type)
#

class BusinessValidationResult < ActiveRecord::Base
  belongs_to :business_validation_template
  belongs_to :validatable, polymorphic: true
  has_many :business_validation_rule_results, dependent: :destroy, inverse_of: :business_validation_result, autosave: true
  scope :public, joins(:business_validation_template).where(business_validation_templates: {private: [nil, false]})

  def can_view? user
    if self.business_validation_template.private?
      user.view_all_business_validation_results?
    else
      user.view_business_validation_results?
    end
  end

  def can_edit? user
    if self.business_validation_template.private?
      user.edit_all_business_validation_results?
    else
      user.edit_business_validation_results?
    end
  end

  def run_validation
    run_validation_internal[:changed]
  end

  def run_validation_with_state_tracking
    run_validation_internal
  end

  def run_validation_internal 
    original_state = self.state
    base_state = 'Skipped'
    results = self.business_validation_rule_results
    validation_states = results.collect do |r|
      r.run_validation_with_state_tracking self.validatable
    end

    validation_states.each do |state|
      base_state = self.class.worst_state(base_state, state[:new_state])
    end

    self.state = base_state
    # return true if state changed
    return {changed: (original_state != self.state), rule_states: validation_states}
  end
  private :run_validation_internal

  def self.worst_state s1, s2
    r = [s1,s2].sort do |a,b|
      return a if fail_state?(a)
      return b if fail_state?(b)
      return a if review_state?(a)
      return b if review_state?(b)
      return a if pass_state?(a)
      return b if pass_state?(b)
      return a if skipped_state?(a)
      return b if skipped_state?(b)
      return a
    end
    r.first
  end

  def failed?
    self.class.fail_state? self.state
  end

  def review?
    self.class.review_state? self.state
  end

  def pass?
    self.class.pass_state? self.state
  end

  def skipped?
    self.class.skipped_state? self.state
  end

  def self.fail_state? state
    state.to_s.upcase.strip == "FAIL"
  end

  def self.review_state? state
    state.to_s.upcase.strip == "REVIEW"
  end

  def self.pass_state? state
    state.to_s.upcase.strip == "PASS"
  end

  def self.skipped_state? state
    state.to_s.upcase.strip == "SKIPPED"
  end
end

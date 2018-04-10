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

  def can_view? user
    user.view_business_validation_results?
  end

  def can_edit? user
    user.edit_business_validation_results?
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
      return a if a=='Fail'
      return b if b=='Fail'
      return a if a=='Review'
      return b if b=='Review'
      return a if a=='Pass'
      return b if b=='Pass'
      return a if a=='Skipped'
      return b if b=='Skipped'
      return a
    end
    r.first
  end

  def failed?
    self.state == "Fail"
  end
end

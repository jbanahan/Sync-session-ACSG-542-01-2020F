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
    original_state = self.state
    base_state = 'Skipped'
    results = self.business_validation_rule_results
    validation_states = results.collect do |r|
      r.run_validation self.validatable
      r.state
    end
    validation_states.uniq.each do |vs|
      base_state = self.class.worst_state(base_state,vs)
    end
    self.state = base_state
    # return true if state changed
    return original_state != self.state
  end

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

class BusinessValidationResult < ActiveRecord::Base
  belongs_to :business_validation_template
  belongs_to :validatable, polymorphic: true, touch: true
  has_many :business_validation_rule_results, dependent: :destroy, inverse_of: :business_validation_result, autosave: true

  def run_validation
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
end

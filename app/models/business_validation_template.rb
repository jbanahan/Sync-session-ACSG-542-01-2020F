class BusinessValidationTemplate < ActiveRecord::Base
  attr_accessible :description, :module_type, :name
  validates :module_type, presence: true
  
  has_many :business_validation_rules, dependent: :destroy, inverse_of: :business_validation_template
  has_many :business_validation_results, inverse_of: :business_validation_template
  has_many :search_criterions, dependent: :destroy

  def create_result! obj
    bvr = nil
    self.search_criterions.each do |sc|
      return nil unless sc.test?(obj)
    end
    self.class.transaction do
      bvr = self.business_validation_results.new
      bvr.validatable = obj
      bvr.save!
      self.business_validation_rules.each do |rule|
        rr = bvr.business_validation_rule_results.new
        rr.business_validation_rule = rule
        rr.save!
      end
    end
    bvr
  end
end

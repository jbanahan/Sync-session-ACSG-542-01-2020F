class CustomViewTemplate < ActiveRecord::Base
  has_many :search_criterions, dependent: :destroy

  attr_accessible :template_identifier, :template_path, :module_type
  validates :module_type, presence: true

  def self.for_object template_identifier, base_object, default=nil
    CustomViewTemplate.includes(:search_criterions).where(template_identifier:template_identifier).each do |cvt|
      passed = true
      cvt.search_criterions.each do |sc|
        if !sc.test?(base_object)
          passed = false
          break
        end
      end
      return cvt.template_path if passed
    end
    return default
  end
end

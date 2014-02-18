require 'open_chain/stat_client'
class BusinessValidationTemplate < ActiveRecord::Base
  attr_accessible :description, :module_type, :name
  validates :module_type, presence: true
  
  has_many :business_validation_rules, dependent: :destroy, inverse_of: :business_validation_template
  has_many :business_validation_results, inverse_of: :business_validation_template
  has_many :search_criterions, dependent: :destroy

  # call create_results! for all templates
  def self.create_all! run_validation = false
    OpenChain::StatClient.wall_time 'bvt_create_all' do
      self.all.each do |b| 
        b.create_results!(run_validation) 
      end
    end
  end
  #run create
  def create_results! run_validation = false
    cm = CoreModule.find_by_class_name(self.module_type)
    klass = cm.klass 
    srch = klass.select("DISTINCT #{cm.table_name}.*").where("#{cm.table_name}.updated_at > business_validation_results.updated_at OR business_validation_results.updated_at is null")
    srch = srch.joins("LEFT OUTER JOIN business_validation_results ON business_validation_results.validatable_type = '#{self.module_type}' AND business_validation_results.validatable_id = #{cm.table_name}.id")
    self.search_criterions.each {|sc| srch = sc.apply(srch)}
    srch.each do |obj|
      self.create_result! obj, run_validation
    end
  end
  def create_result! obj, run_validation = false
    bvr = nil
    self.search_criterions.each do |sc|
      return nil unless sc.test?(obj)
    end
    self.class.transaction do
      bvr = self.business_validation_results.where(validatable_type:obj.class.name,validatable_id:obj.id).first_or_create!
      bvr.validatable = obj
      bvr.save!
      self.business_validation_rules.each do |rule|
        bvr.business_validation_rule_results.where(business_validation_rule_id:rule.id).first_or_create!
      end
    end
    if run_validation
      bvr.run_validation
      bvr.updated_at = Time.now #force save
      bvr.save!
    end
    bvr
  end
end

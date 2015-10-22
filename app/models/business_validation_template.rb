require 'open_chain/stat_client'
# This is kind of weird but because of the way the invoice line rule extends the validation rule the load ordering 
# matters here, so the validation rule is required first
require 'business_validation_rule'
# Any customer specific business rule should be required below here
require 'open_chain/custom_handler/polo/polo_validation_rule_entry_invoice_line_matches_po_line'

class BusinessValidationTemplate < ActiveRecord::Base
  attr_accessible :description, :module_type, :name
  validates :module_type, presence: true
  
  has_many :business_validation_rules, dependent: :destroy, inverse_of: :business_validation_template
  has_many :business_validation_results, inverse_of: :business_validation_template
  has_many :search_criterions, dependent: :destroy

  def self.run_schedulable opts = {}
    opts = {'run_validation' => true}.merge opts
    create_all! opts['run_validation'] != false
  end

  # call create_results! for all templates
  def self.create_all! run_validation = false
    OpenChain::StatClient.wall_time 'bvt_create_all' do
      self.all.each do |b| 
        b.create_results!(run_validation) 
      end
    end
  end

  # call create_result for all templates with matching module types
  # for the given object
  def self.create_results_for_object! obj
    cm = CoreModule.find_by_object(obj)
    return if cm.nil?
    BusinessValidationTemplate.where(module_type:cm.class_name).each do |bvt|
      bvt.create_result!(obj,true)
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
      begin
        self.create_result! obj, run_validation
      rescue => e
        # Don't let one bad object spoil the whole rule run
        e.log_me ["Failed to generate rule results for #{obj.class} id #{obj.id}"]
      end
    end
  end

  def create_result! obj, run_validation = false
    bvr = nil
    self.search_criterions.each do |sc|
      return nil unless sc.test?(obj)
    end

    # This should prevent multiple business validation result objects from being generated at a time (.ie if there are concurrent create_all! runs occurring)
    # I'm not putting this in a super-coarse lock around create_all! because that will run the whole create_all! method inside a single DB transaction,
    # which has the potential to be a very lengthy process.
    bvr = nil
    Lock.with_lock_retry(self) do
      bvr = self.business_validation_results.where(validatable_type:obj.class.name,validatable_id:obj.id).first_or_create!
    end

    # Create the rule results and then run the validations (if requested) all inside a lock on the validation result.
    # This should mean that only a single process is running validations for this module obj at a time
    Lock.with_lock_retry(bvr) do
      bvr.validatable = obj
      bvr.save!

      self.business_validation_rules.each do |rule|
        bvr.business_validation_rule_results.where(business_validation_rule_id:rule.id).first_or_create!
      end

      if run_validation
        bvr.run_validation
        bvr.updated_at = Time.now #force save
        bvr.save!
      end
    end
    
    bvr
  end
end

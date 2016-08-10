require 'open_chain/stat_client'
# This is kind of weird but because of the way the invoice line rule extends the validation rule the load ordering 
# matters here, so the validation rule is required first
require 'business_validation_rule'
# Any customer specific business rule should be required below here
require 'open_chain/custom_handler/polo/polo_validation_rule_entry_invoice_line_matches_po_line'
require 'open_chain/custom_handler/ascena/validation_rule_ascena_invoice_audit'
require 'open_chain/custom_handler/lumber_liquidators/lumber_validation_rule_entry_invoice_part_matches_order'
require 'open_chain/custom_handler/pepsi/quaker_validation_rule_po_number_unique'

class BusinessValidationTemplate < ActiveRecord::Base
  attr_accessible :description, :module_type, :name, :delete_pending
  validates :module_type, presence: true
  
  has_many :business_validation_rules, dependent: :destroy, inverse_of: :business_validation_template
  has_many :business_validation_results, dependent: :destroy, inverse_of: :business_validation_template
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

    nil
  end

  #run create
  def create_results! run_validation = false
    # Bailout if the template doesn't have any search criterions...without any criterions you'll literally pick up every line in the system associated
    # with the module_type associated with the template...which is almost certainly not what you'd want.  If it REALLY is, then create a criterion that will
    # never be false associated with the template
    return if self.search_criterions.length == 0
    
    cm = CoreModule.find_by_class_name(self.module_type)
    klass = cm.klass 
    # Use distinct id rather than * so we're not forcing the DB to run a distinct over a large set of columns, when the only value it actually needs to be 
    # distinct is the core module's id.
    srch = klass.select("DISTINCT #{cm.table_name}.id").where("#{cm.table_name}.updated_at > business_validation_results.updated_at OR business_validation_results.updated_at is null")
    srch = srch.joins("LEFT OUTER JOIN business_validation_results ON business_validation_results.validatable_type = '#{self.module_type}' AND business_validation_results.validatable_id = #{cm.table_name}.id AND business_validation_results.business_validation_template_id = #{self.id}")
    self.search_criterions.each {|sc| srch = sc.apply(srch)}
    srch.each do |id|
      obj = nil
      begin
        # Use this rather than find, since it's possible, though unlikely, that the obj has been removed from the system since being returned from the query above
        obj = klass.where(id: id.id).first
        self.create_result!(obj, run_validation) unless obj.nil?
      rescue => e
        # Don't let one bad object spoil the whole rule run
        if obj
          e.log_me ["Failed to generate rule results for #{obj.class} id #{obj.id}"]
        else
          e.log_me
        end
      end
    end
  end

  def create_result! obj, run_validation = false
    # Bailout if the template doesn't have any search criterions...without any criterions you'll literally pick up every line in the system associated
    # with the module_type associated with the template...which is almost certainly not what you'd want.  If it REALLY is, then create a criterion that will
    # never be false associated with the template
    return nil if self.search_criterions.length == 0

    template_applies = false
    self.search_criterions.each do |sc|
      template_applies = sc.test?(obj)
      break unless template_applies
    end

    # Check to see if there are any rule results around for this template, if so, we need to remove them as the template no longer applies.
    # This could be the case is situations where a template was changed to remove a company from the rules.
    if !template_applies
      result = obj.business_validation_results.where(business_validation_template_id: self.id).first
      result.destroy if result
      return nil
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
        unless rule.delete_pending?
          bvr.business_validation_rule_results.where(business_validation_rule_id:rule.id).first_or_create!
        end
      end

      if run_validation
        bvr.run_validation
        bvr.updated_at = Time.zone.now #force save
        bvr.save!

        # Because of the way we're embedding this inside result_result! (which runs only for a single template), objects
        # that have multiple rule templates associated with them will have extra snapshots.  This situation occurs
        # infrequently enough that I'm not worrying about it now (only 750 total of 100K's of records we have are linked to multiple
        # templates - pretty sure even those are due to bad initial template setups)
        BusinessRuleSnapshot.create_from_entity(obj)
      end
    end
    
    bvr
  end

  def self.async_destroy id
    template = find_by_id id
    template.destroy if template
  end
end

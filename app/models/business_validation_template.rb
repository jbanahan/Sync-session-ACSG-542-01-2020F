# == Schema Information
#
# Table name: business_validation_templates
#
#  created_at     :datetime         not null
#  delete_pending :boolean
#  description    :string(255)
#  disabled       :boolean
#  id             :integer          not null, primary key
#  module_type    :string(255)      not null
#  name           :string(255)
#  private        :boolean
#  system_code    :string(255)
#  updated_at     :datetime         not null
#

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
  attr_accessible :description, :module_type, :name, :delete_pending, :disabled, :private, :system_code
  validates :module_type, presence: true
  validates :system_code, uniqueness: true, if: lambda { system_code.present? }

  has_many :business_validation_rules, dependent: :destroy, inverse_of: :business_validation_template
  has_many :business_validation_results, dependent: :destroy, inverse_of: :business_validation_template
  has_many :search_criterions, dependent: :destroy

  def copy_attributes include_external:false
    attrs = JSON.parse self.to_json(except: [:id, :system_code, :created_at, :updated_at, :delete_pending, :disabled])
    attrs["business_validation_template"]["search_criterions"] = self.search_criterions.map(&:copy_attributes)
    attrs["business_validation_template"]["business_validation_rules"] = self.business_validation_rules.map{ |r| r.copy_attributes(include_external: include_external) }
    attrs
  end

  def self.parse_copy_attributes template_hsh
    template = BusinessValidationTemplate.new(template_hsh["business_validation_template"].reject{ |k,v| ["search_criterions", "business_validation_rules"].include? k })
    bvt_hsh = template_hsh["business_validation_template"]
    bvt_hsh["search_criterions"].each{ |sc_hsh| template.search_criterions << SearchCriterion.new(sc_hsh["search_criterion"]) }
    bvt_hsh["business_validation_rules"].each do |bvru_hsh| 
      template.business_validation_rules << BusinessValidationRule.parse_copy_attributes(bvru_hsh) 
    end
    template
  end

  def self.run_schedulable opts = {}
    opts = {'run_validation' => true}.merge opts
    create_all! run_validation: (opts['run_validation'] != false)
  end

  # call create_results! for all templates
  def self.create_all! run_validation: false
    OpenChain::StatClient.wall_time 'bvt_create_all' do
      self.all.each do |b|
        b.create_results!(run_validation: run_validation)
      end
    end
  end

  # This is pretty much just a simple way to offload rule validation of a bunch of object ids 
  # to a backend processing queue.  The standard use case for this would be:
  #
  # BusinessValidationTemplate.delay.create_results_for_object_ids! "Product", [1, 2, 3]
  #
  def self.create_results_for_object_ids! object_type, object_ids, snapshot_entity: true
    object_type = object_type.constantize unless object_type.is_a?(Class)

    Array.wrap(object_ids).each do |id|
      object = object_type.where(id: id).first
      create_results_for_object!(object, snapshot_entity: snapshot_entity) if object
    end
  end

  # call create_result for all templates with matching module types
  # for the given object
  def self.create_results_for_object! obj, snapshot_entity: true, user: nil
    cm = CoreModule.find_by_object(obj)
    return if cm.nil?

    tracking_results = []
    BusinessValidationTemplate.where(module_type:cm.class_name).each do |bvt|
      tracking_results << bvt.create_result!(obj, run_validation: true, snapshot_entity: snapshot_entity)
    end

    user = User.integration if user.nil?
    handle_snapshots(tracking_results.compact, obj, user, snapshot_entity: snapshot_entity) 

    nil
  end

  def active?
    !self.disabled? && !self.delete_pending? && search_criterions.present?
  end

  #run create
  def create_results! run_validation: false, snapshot_entity: true, user: nil
    # Bailout if the template doesn't have any search criterions...without any criterions you'll literally pick up every line in the system associated
    # with the module_type associated with the template...which is almost certainly not what you'd want.  If it REALLY is, then create a criterion that will
    # never be false associated with the template
    return if self.search_criterions.length == 0

    user = User.integration if user.nil?
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
        result = self.create_result!(obj, run_validation: run_validation) unless obj.nil?
        self.class.handle_snapshots(result, obj, user, snapshot_entity: snapshot_entity) unless result.nil?
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

  def create_result! obj, run_validation: false, snapshot_entity: true
    # Bailout if the template doesn't have any search criterions...without any criterions you'll literally pick up every line in the system associated
    # with the module_type associated with the template...which is almost certainly not what you'd want.  If it REALLY is, then create a criterion that will
    # never be false associated with the template
    return nil unless active?

    template_applies = false
    self.search_criterions.each do |sc|
      template_applies = sc.test?(obj)
      break unless template_applies
    end

    # Check to see if there are any rule results around for this template, if so, we need to remove them as the template no longer applies.
    # This could be the case is situations where a template was changed to remove a company from the rules.
    if !template_applies
      Lock.with_lock_retry(obj) do 
        result = obj.business_validation_results.where(business_validation_template_id: self.id).first
        result.destroy if result
      end
      return nil
    end

    # Inverting the obj/bvr locks is an attempt to reduce the deadlocks in this section of code...the vast majority of 
    # time the calling code will already have obtained a lock on the obj (since this code is called when snapshoting an object)
    # therefore, there's going to be few situations where it shouldn't be able to also obtain the bvr lock for the obj.''
    bvr = nil
    state_tracking = nil
    Lock.with_lock_retry(obj) do 
      bvr = obj.business_validation_results.where(business_validation_template_id: self.id).first_or_create!
      
      Lock.with_lock_retry(bvr) do
        initialize_business_validation_result bvr, obj

        # Create the rule results and then run the validations (if requested) all inside a lock on the validation result.
        # This should mean that only a single process is running validations for this module obj at a time
        if run_validation
          state_tracking = bvr.run_validation_with_state_tracking if process_object_rules?(obj)

          # We only need to save the whole validation result object if something actually changed
          if self.class.state_tracking_changed?(state_tracking)
            bvr.updated_at = Time.zone.now #force save
            bvr.save!
          else
            # If nothing changed, we'll still want to update the rule result's updated_at column so we know if there might be any issue with
            # rules not evaluating by looking at the object's updated_at column and comparing it to the rule result's one (rule result should always be after),
            # but let's do it in the most efficient fashion if nothing about the rule result changed.
            bvr.update_column :updated_at, Time.zone.now
          end
        end
      end
    end
    
    {result: bvr, tracking: state_tracking}
  end

  def self.handle_snapshots state_tracking, obj, user, snapshot_entity: true

    # The only time we want to snapshot the business rules is if any rule changed
    results_changed = Array.wrap(state_tracking).any? {|tracking| !tracking.nil? && state_tracking_changed?(tracking[:tracking]) }

    # We'll want to snapshot if the overall results or any individual rules changed
    if results_changed
      BusinessRuleSnapshot.create_from_entity(obj)
      # There's times where you might not want to snapshot the entity when evaluating business rules (say like when
      # you're actually in the process of generating a snapshot for the entity)
      if snapshot_entity
        obj.create_snapshot(user, nil, "Business Rule Update") if obj.respond_to?(:create_snapshot)
      end
    end
  end

  def self.state_tracking_changed? state_tracking
    # check if any rule state inside the result changed or the overall state
    return false if state_tracking.nil?

    state_tracking[:changed] == true ||
      Array.wrap(state_tracking[:rule_states]).any? {|state| state[:changed] == true }
  end

  def initialize_business_validation_result business_validation_result, obj
    rule_built = false
    self.business_validation_rules.each do |rule|
      if rule.active?
        # Rather than doing a first_or_create for every rule (which used to be here and resulted in a separate query executed for each rule)
        #...we can load the association once and then search through it for the rule id...then build the result if it's not present yet.
        # The result will be created a few lines below when the validation result is saved.
        rule_result = business_validation_result.business_validation_rule_results.find {|bvrr| bvrr.business_validation_rule_id == rule.id }
        if rule_result.nil?
          # the business_validation_rule_id is not an accessible attribute, so we can't use create! business_validation_rule_rule_id: rule.id
          rr = business_validation_result.business_validation_rule_results.build
          rr.business_validation_rule = rule
          rule_built = true
        end
      end
    end

    business_validation_result.save! if rule_built
  end

  def process_object_rules? obj
    # If we have the feature enabled, we should skip processing rules on all closed objects.
    # If we have a closed object and we skip it, we do want to make sure that we still update the business validation results updated_at column
    # otherwise the background job is going to be pulling up this object every single time the job runs to run rules on any objects that have changed.
    if obj.respond_to?(:closed?) && obj.closed?
      return !MasterSetup.get.custom_feature?("Disable Rules For Closed Objects")
    else
      return true
    end
  end

  def self.async_destroy id
    template = find_by_id id
    template.destroy if template
  end
end

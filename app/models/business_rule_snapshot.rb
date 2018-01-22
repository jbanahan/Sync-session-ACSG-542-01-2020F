# == Schema Information
#
# Table name: business_rule_snapshots
#
#  id              :integer          not null, primary key
#  recordable_id   :integer          not null
#  recordable_type :string(255)      not null
#  bucket          :string(255)
#  doc_path        :string(255)
#  version         :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  compared_at     :datetime
#
# Indexes
#
#  business_rule_snapshots_on_recordable_id_and_recordable_type  (recordable_id,recordable_type)
#

require 'open_chain/s3'
require 'open_chain/entity_compare/entity_comparator'

class BusinessRuleSnapshot < ActiveRecord::Base
  include SnapshotS3Support

  belongs_to :recordable, polymorphic: true

  # Returns the data about when the rules associated with the entity transitioned from one state to another
  def self.rule_comparisons entity
    rule_changes = []
    snapshots = BusinessRuleSnapshot.where(recordable_id: entity.id, recordable_type: recordable_type(entity)).order("created_at ASC")

    # Establish a baseline for each rule and track when their state changes, all we need to track is the rule id (which is a hash key
    # in the history data) and the value.  All the other data is ancillary.
    # We can use the same hash for all templates, since we're keying on rule id...which will be unique across any template
    rule_history = {}

    snapshots.each do |s|
      json = retrieve_snapshot_data_from_s3 s
      next if json.blank?

      data = ActiveSupport::JSON.decode(json).with_indifferent_access

      data[:templates].each_pair do |template_id, template_data|
        template_data[:rules].each_pair do |rule_id, rule_data|
          if rule_history[rule_id] != rule_data[:state]
            rule_changes << create_rule_data(template_data, rule_data)
            rule_history[rule_id] = rule_data[:state]
          end
        end
      end
    end

    rule_changes
  end

  def self.create_rule_data template_data, rule_data
    # Just stuff the template name into the rule_data hash for now...if we need to 
    # we can create a more formalized data object as a Struct or somethign later, for now
    # this is good enough
    data = rule_data.deep_dup
    data[:template_name] = template_data[:name]
    data[:template_description] = template_data[:description]

    # Convert the times to actual date objects
    data[:updated_at] = Time.zone.parse data[:updated_at] unless data[:updated_at].blank?
    data[:created_at] = Time.zone.parse data[:created_at] unless data[:created_at].blank?
    data[:overridden_at] = Time.zone.parse data[:overridden_at] unless data[:overridden_at].blank?

    data
  end
  private_class_method :create_rule_data

  # Creates a snapshot of all the business rules states associated with the given entity
  def self.create_from_entity entity
    snapshot_json = ActiveSupport::JSON.encode(generate_snapshot_data entity)
    snapshot = BusinessRuleSnapshot.create! recordable: entity
    begin
      s3_data = write_to_s3 snapshot_json, entity, path_prefix: "business_rule"
      snapshot.update_attributes! bucket: s3_data[:bucket], version: s3_data[:version], doc_path: s3_data[:key] 
      OpenChain::EntityCompare::EntityComparator.handle_snapshot snapshot
    rescue Exception => e
      # If we fail to write the snapshot to S3, buffer the data in the database and then 
      # another service will come along and process it, push it to s3 and then relink the s3 data to the
      # snapshot.
      EntitySnapshotFailure.create! snapshot: snapshot, snapshot_json: snapshot_json
    end
    snapshot
  end

  def self.generate_snapshot_data entity
    recordable_id = entity.id
    recordable_type = recordable_type(entity)

    templates = {}
    entity.business_validation_results.each do |result|
      template = result.business_validation_template
      t_key = "template_#{template.id}"
      template_obj = templates[t_key]
      if template_obj.nil?
        template_obj = template_data(recordable_id, recordable_type, template, result)
        templates[t_key] = template_obj
      end

      result.business_validation_rule_results.each do |rule_result|
        key, data = *rule_data(rule_result)
        next if key.nil?

        template_obj[:rules][key] = data
      end
    end

    {recordable_id: recordable_id, recordable_type: recordable_type, templates: templates}
  end
  private_class_method :generate_snapshot_data

  def self.recordable_type recordable
    recordable.class.to_s
  end
  private_class_method :recordable_type

  def self.template_data recordable_id, recordable_type, template, result
    {name: template.name, description: template.description, state: result.state, rules: {}}
  end
  private_class_method :template_data

  def self.rule_data result
    rule = result.business_validation_rule
    # Rule could technically be nil if were in a state where the rule was deleted and its in the process of getting cleaned up
    return nil if rule.nil?
    ["rule_#{rule.id}", {type: rule.try(:type), name: rule.try(:name), description: rule.description, notification_type: rule.try(:notification_type), fail_state: rule.try(:fail_state), state: result.state, message: result.message, note: result.note, overridden_by_id: result.overridden_by_id, overridden_at: result.overridden_at, created_at: result.created_at, updated_at: result.updated_at }]
  end
  private_class_method :rule_data
end

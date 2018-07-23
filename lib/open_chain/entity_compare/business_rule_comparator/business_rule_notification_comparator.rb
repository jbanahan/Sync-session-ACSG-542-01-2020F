require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/entity_compare/business_rule_comparator'

module OpenChain; module EntityCompare; module BusinessRuleComparator; class BusinessRuleNotificationComparator
  extend OpenChain::EntityCompare::BusinessRuleComparator
  extend OpenChain::EntityCompare::ComparatorHelper

  PASS_STATE = ['Pass', 'Skipped']
  
  def self.accept? snapshot
    return false unless super
    return false unless snapshot.recordable

    # Only accept if any of the rules associated w/ the object actually have a notification type set up
    snapshot.recordable.business_validation_results.each do |result|
      result.business_validation_template.business_validation_rules.each do |rule|
        return true if !rule.notification_type.blank?
      end if result.business_validation_template
    end

    false
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    new_rules = rules_for_processing(get_json_hash(new_bucket, new_path, new_version))
    return unless new_rules.present?
    old_rules = rules_for_processing(get_json_hash(old_bucket, old_path, old_version))
    uid, customer_number, importer_name = extract_obj_info(id, type)
    changed_rules(old_rules, new_rules).each { |rule| update(rule, type, id, uid, customer_number, importer_name) }
  end

  def self.rules_for_processing json_hash
    return unless json_hash.present?
    rules = {}
    json_hash["templates"].each do |t_key, t|
      t["rules"].each do |r_key, r| 
        if r["notification_type"].present? 
          rules[r_key] = r 
          rules[r_key]["id"] = extract_id(r_key).to_i
        end
      end
    end
    rules
  end

  def self.changed_rules old_rules, new_rules
    changed = []
    new_rules.each do |r_key, r|
      if !old_rules.try(:[], r_key).present?
        changed << r unless PASS_STATE.member? r["state"]
      else
        changed << r unless (r["state"] == old_rules[r_key]["state"]) || (PASS_STATE.member?(r["state"]) && PASS_STATE.member?(old_rules[r_key]["state"]))
      end
    end
    changed
  end

  def self.update rule_json, type, id, uid, customer_number, importer_name
    if rule_json["notification_type"] == 'Email'
      rule_obj = BusinessValidationRule.find(rule_json["id"])
      send_email(id: id, rule: rule_obj, module_type: type, uid: uid, state: rule_json["state"], description: rule_json["description"], 
                 message: rule_json["message"], customer_number: customer_number, importer_name: importer_name)
    end
  end

  def self.send_email id:, rule:, module_type:, uid:, state:, description:, message:, customer_number:, importer_name:
    subject = %Q(#{module_type} - #{uid} - #{state}: #{description_override(rule, state)[:subject].presence || description})
    body = ""
    body += %Q(<p>#{customer_number}</p>) if customer_number.present?
    body += %Q(<p>#{importer_name}</p>) if importer_name.present?
    body += %Q(<p>#{description_override(rule, state)[:message].presence || "Rule Description: " + description}</p>)
    body += %Q(<p>#{module_type} #{uid} rule status has changed to '#{state}' </p>)
    body += %Q(<p>#{message}</p>)
    body += %Q(<p>#{link id, module_type}</p>)
    OpenMailer.send_simple_html(rule.notification_recipients, subject, body.html_safe, [], {suppressed: suppress_email?(rule, state)}).deliver!
  end
  
  private

  def self.description_override rule, state
    case state
    when "Pass"
      {subject: rule.subject_pass, message: rule.message_pass}
    when "Fail", "Review"
      {subject: rule.subject_review_fail, message: rule.message_review_fail}
    when "Skipped"
      {subject: rule.subject_skipped, message: rule.message_skipped}
    end
  end

  def self.suppress_email? rule, state
    case state
    when "Pass"
      rule.suppress_pass_notice?
    when "Fail", "Review"
      rule.suppress_review_fail_notice?
    when "Skipped"
      rule.suppress_skipped_notice?
    end
  end
  
  def self.extract_obj_info id, module_type
    mod = CoreModule.find_by_class_name module_type
    obj = module_type.constantize.find(id)
    uid = mod.unique_id_field.process_export(obj, nil)
    [uid, customer_number(module_type, obj), obj.try(:importer).try(:name)]
  end

  def self.customer_number module_type, obj
    obj.customer_number if module_type == "Entry"
  end

  def self.extract_id key
    /(?<=_)\d+/.match(key)[0]
  end

  def self.link id, module_type
    helper = module_type.downcase + "_url"
    Rails.application.routes.url_helpers.send(helper, id, host: MasterSetup.get.request_host, protocol: (Rails.env.production? ? "https" : "http"))
  end

end; end; end; end

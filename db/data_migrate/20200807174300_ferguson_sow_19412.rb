class FergusonSow19412 < ActiveRecord::Migration

  def up
    return unless MasterSetup.get.custom_feature?("WWW")

    ferg = Company.with_customs_management_number("FERENT").first
    raise "Ferguson company not found" unless ferg

    job = SchedulableJob.where(run_class: "OpenChain::CustomHandler::Ferguson::FergusonEntryVerificationXmlGenerator").first_or_create!
    job.update! run_hour: 2, run_minute: 0, time_zone_name: "Eastern Time (US & Canada)", stopped: true

    ml = MailingList.where(company_id: ferg.id, system_code: "ferguson_rule_failures", name: "Ferguson Rule Failures", user: User.integration).first_or_create!
    ml.update! email_addresses: "InternationalTrade.US@Ferguson.com"

    add_business_validation_rule ml
  end

  def add_business_validation_rule ml
    bvt = BusinessValidationTemplate.where(module_type: 'Entry', name: 'Ferguson Entry Rules', description: 'Validate required fields for Entry Verification').first_or_create!
    bvt.search_criterions.where(operator: "eq", model_field_uid: "ent_cust_num", value: "FERENT").first_or_create!
    bvt.search_criterions.where(operator: "notnull", model_field_uid: "ent_release_date", value: "").first_or_create!
    bvt.update!(
      private: false,
      disabled: false
    )

    bvr = bvt.business_validation_rules.where(type: 'OpenChain::CustomHandler::Ferguson::FergusonMandatoryEntryFieldRule', name: 'Mandatory Fields', description: "Mandatory fields required to populate the outbound Entry verification file.").first_or_create!
    bvr.update!(
      fail_state: "Fail",
      disabled: false,
      notification_type: "Email",
      mailing_list_id: ml.id
    )
  end

  def down
    return unless MasterSetup.get.custom_feature?("WWW")

    BusinessValidationTemplate.where(module_type: 'Entry', name: 'Ferguson Entry Rules').destroy_all
    SchedulableJob.where(run_class: "OpenChain::CustomHandler::Ferguson::FergusonEntryVerificationXmlGenerator").destroy_all
    MailingList.where(system_code: "ferguson_rule_failures", name: "Ferguson Rule Failures").destroy_all
  end

end
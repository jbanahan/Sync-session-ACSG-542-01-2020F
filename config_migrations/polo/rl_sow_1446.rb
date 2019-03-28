require 'open_chain/custom_handler/polo/polo_custom_definition_support'
module ConfigMigrations; module Polo; class RlSow1446
  include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

  def up
    cdefs
    add_field_validations
    adjust_schedulable_jobs_up
    add_mailing_lists
    nil
  end

  def down
    delete_field_validations
    adjust_schedule_jobs_down
    remove_mailing_lists
    nil
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([
      :merchandising_fabrication, :product_class_description, :material_status, :ax_export_status, :heel_height, :sap_brand_name,
      :gcc_description_2, :gcc_description_3, :non_textile
    ])
  end

  def add_field_validations
    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:material_status].model_field_uid).first_or_create!
    fvr.one_of = "\nINACTIVE\nACTIVE"
    fvr.save!

    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:ax_export_status].model_field_uid).first_or_create!
    fvr.one_of = "\nEXPORTED\nSUBMITTED\nNOT EXPORTED"
    fvr.save!

    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:non_textile].model_field_uid).first_or_create!
    fvr.one_of = "\nY\nN"
    fvr.save!

    nil
  end

  def delete_field_validations
    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:material_status].model_field_uid).first
    fvr.destroy if fvr.present?

    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:ax_export_status].model_field_uid).first
    fvr.destroy if fvr.present?

    fvr = FieldValidatorRule.where(model_field_uid:cdefs[:non_textile].model_field_uid).first
    fvr.destroy if fvr.present?

    nil
  end

  def adjust_schedulable_jobs_up
    # We're going to remove the MSL product generator schedulable job and replace it with the new AX product generator
    SchedulableJob.where(run_class: "OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler").destroy_all

    # RL wants the job to run every 6 hours @ 1am, 7am, 1pm, 7pm
    SchedulableJob.where(run_class: "OpenChain::CustomHandler::Polo::PoloAxProductGenerator").first_or_create! no_concurrent_jobs: true, time_zone_name: "Eastern Time (US & Canada)", run_interval: "0 1,7,13,19 * * *"
  end

  def adjust_schedule_jobs_down
    SchedulableJob.where(run_class: "OpenChain::CustomHandler::Polo::PoloAxProductGenerator").destroy_all

    SchedulableJob.where(run_class: "OpenChain::CustomHandler::PoloMslPlusEnterpriseHandler").first_or_create! no_concurrent_jobs: true, time_zone_name: "Eastern Time (US & Canada)", run_interval: "0 19 * * *"
  end

  def add_mailing_lists
    rl = Company.where(master: true).first
    user = User.integration
    MailingList.where(system_code: "ax_products_ack").first_or_create!(name: "AX Product Ack Errors", user_id: user.id, company_id: rl.id, email_addresses: "dalyn.lombardi@ralphlauren.com, tiffani.bratton@ralphlauren.com, ivette.ocasio@ralphlauren.com, kristina.rodriguez@ralphlauren.com", hidden: true)
    MailingList.where(system_code: "csm_products_ack").first_or_create!(name: "CSM Product Ack Errors", user_id: user.id, company_id: rl.id, email_addresses: "dalyn.lombardi@ralphlauren.com", hidden: true)
    MailingList.where(system_code: "efocus_products_ack").first_or_create!(name: "e-Focus Product Ack Errors", user_id: user.id, company_id: rl.id, email_addresses: "dalyn.lombardi@ralphlauren.com", hidden: true)
    nil
  end

  def remove_mailing_lists
    MailingList.where(system_code: ["ax_products_ack", "csm_products_ack", "efocus_products_ack"]).destroy_all
    nil
  end

end; end; end
require 'open_chain/custom_handler/target/target_entry_consolidation_report'

class TargetEntryConsolidation1998 < ActiveRecord::Migration
  def up
    return unless MasterSetup.get.custom_feature?("Target")

    # Prevents the first run of the consolidation report from including all previous entries.
    sd = SystemDate.where(date_type: OpenChain::CustomHandler::Target::TargetEntryConsolidationReport::LAST_REPORT_RUN).first_or_create!
    sd.update! start_date: ActiveSupport::TimeZone["America/New_York"].now

    c = Company.with_customs_management_number("TARGEN").first
    ml = MailingList.where(system_code: "Target Entry Consolidation Report", company: c, name: "Target Entry Consolidation Report", user: User.integration).first_or_create!
    ml.update!(email_addresses: "target@vandegriftinc.com, dbernardini@vandegriftinc.com, mgrignon@vandegriftinc.com")

    job = SchedulableJob.where(run_class: "OpenChain::CustomHandler::Target::TargetEntryConsolidationReport").first_or_create!
    job.update! stopped: !MasterSetup.get.production?, run_sunday: true, run_monday: true, run_tuesday: true,
                run_wednesday: true, run_thursday: true, run_friday: true, run_saturday: true,
                time_zone_name: "Eastern Time (US & Canada)", run_interval: "10m", no_concurrent_jobs: true
  end

  def down
    SystemDate.where(date_type: OpenChain::CustomHandler::Target::TargetEntryConsolidationReport::LAST_REPORT_RUN).destroy_all
    MailingList.where(system_code: "Target Entry Consolidation Report").destroy_all
    SchedulableJob.where(run_class: "OpenChain::CustomHandler::Target::TargetEntryConsolidationReport").destroy_all
  end
end
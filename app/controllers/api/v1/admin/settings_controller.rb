module Api; module V1; module Admin; class SettingsController < Api::V1::Admin::AdminApiController

  def paths
    urls = {  # general
               attachment_types: attachment_types_path,
               charge_codes: charge_codes_path,
               commercial_invoice_maps: commercial_invoice_maps_path,
               companies: companies_path,
               countries: countries_path,
               instant_classifications: instant_classifications_path,
               linkable_attachment_import_rules: linkable_attachment_import_rules_path,
               new_bulk_messages: new_bulk_messages_path,
               milestone_plans: milestone_plans_path,
               ports: ports_path,
               product_groups: product_groups_path,
               entity_types: entity_types_path,
               regions: regions_path,
               search_templates: search_templates_path,
               status_rules: status_rules_path,
               show_system_message_master_setups: show_system_message_master_setups_path,
               settings_system_summary: settings_system_summary_path,
               tariff_sets: tariff_sets_path,
               user_manuals: user_manuals_path,
               user_templates: user_templates_path,
               worksheet_configs: worksheet_configs_path,
               run_as_logs: run_as_sessions_path,
             
              # field
               field_labels: field_labels_path,
               custom_definitions: custom_definitions_path,
               public_fields: "/public_fields",
               field_validator_rules: field_validator_rules_path,
             
              # sys-admin
               master_setups: master_setups_path,
               error_log_entries: error_log_entries_path,
               schedulable_jobs: schedulable_jobs_path,
               custom_view_templates: custom_view_templates_path,
               state_toggle_buttons: state_toggle_buttons_path,
               search_table_configs: search_table_configs_path,
               milestone_notification_configs: MasterSetup.get.custom_feature?("Entry 315") ? milestone_notification_configs_path : nil,
               aws_backup_sessions: aws_backup_sessions_path,
               alert_reference_fields: reference_fields_index_one_time_alerts_path
           }
    render json: urls
  end

end; end; end; end

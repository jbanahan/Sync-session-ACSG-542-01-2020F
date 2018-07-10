Dir.glob(File.dirname(__FILE__) + '/report/*') {|file| require file}
require 'open_chain/custom_handler/lumber_liquidators/lumber_dhl_order_push_report'
require 'open_chain/custom_handler/j_crew/j_crew_drawback_imports_report'
require 'open_chain/custom_handler/lumber_liquidators/lumber_actualized_charges_report'
require 'open_chain/custom_handler/polo/polo_jira_entry_report'
require 'open_chain/custom_handler/ascena/ascena_duty_savings_report'
require 'open_chain/custom_handler/ascena/ascena_vendor_scorecard_report'
require 'open_chain/custom_handler/lumber_liquidators/lumber_order_snapshot_discrepancy_report'

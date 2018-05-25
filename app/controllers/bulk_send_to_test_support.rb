require 'open_chain/bulk_action/bulk_action_runner'
require 'open_chain/bulk_action/bulk_action_support'
require 'open_chain/bulk_action/bulk_send_to_test'

# Controller classes including this module need to contain a method, root_class, for this process to work.
module BulkSendToTestSupport
  include OpenChain::BulkAction::BulkActionSupport

  def bulk_send_last_integration_file_to_test
    begin
      opts = { 'module_type': root_class.try(:name), 'max_results': 100 }
      OpenChain::BulkAction::BulkActionRunner.process_from_parameters current_user, params, OpenChain::BulkAction::BulkSendToTest, opts
      add_flash :notices, "Integration files have been queued to be sent to test."
    rescue OpenChain::BulkAction::TooManyBulkObjectsError => e
      add_flash :errors, "You may not send more than 100 files to test at one time."
    end
    redirect_back_or_default :back
  end
end
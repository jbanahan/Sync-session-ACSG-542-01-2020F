require 'open_chain/custom_handler/intacct/intacct_data_pusher'

class IntacctErrorsController < ApplicationController
  VFI_ACCOUNTING_USERS ||= 'intacct-accounting'

  def index
    action_secure(IntacctErrorsController.allowed_user?(current_user), nil, verb: 'view', module_name: "page") do
      @payables = IntacctPayable.where(intacct_key: nil).where("intacct_errors IS NOT NULL").all
      @receivables = IntacctReceivable.where(intacct_key: nil).where("intacct_errors IS NOT NULL").all
      @checks = IntacctCheck.where(intacct_key: nil).where("intacct_errors IS NOT NULL").all
    end
  end

  def clear_payable 
    action_secure(IntacctErrorsController.allowed_user?(current_user), nil, verb: 'view', module_name: "Payable") do
      intacct_object = IntacctPayable.where(id: params[:id]).first

      if intacct_object.nil?
        add_flash :errors, "No Intacct Error message found to clear."
      else
        intacct_object.update_attributes! intacct_errors: nil
        add_flash :notices, "Intacct Error message has been cleared.  The Payable will be re-sent when the next integration process runs."
      end

      redirect_to action: "index"
    end
  end

  def clear_receivable
    action_secure(IntacctErrorsController.allowed_user?(current_user), nil, verb: 'view', module_name: "Receivable") do
      intacct_object = IntacctReceivable.where(id: params[:id]).first

      if intacct_object.nil?
        add_flash :errors, "No Intacct Error message found to clear."
      else
        intacct_object.update_attributes! intacct_errors: nil
        add_flash :notices, "Intacct Error message has been cleared.  The Receivable will be re-sent when the next integration process runs."
      end

      redirect_to action: "index"
    end
  end

  def clear_check
    action_secure(IntacctErrorsController.allowed_user?(current_user), nil, verb: 'view', module_name: "Check") do
      intacct_object = IntacctCheck.where(id: params[:id]).first

      if intacct_object.nil?
        add_flash :errors, "No Intacct Error message found to clear."
      else
        intacct_object.update_attributes! intacct_errors: nil
        add_flash :notices, "Intacct Error message has been cleared.  The Check will be re-sent when the next integration process runs."
      end

      redirect_to action: "index"
    end
  end

  def push_to_intacct
    action_secure(IntacctErrorsController.allowed_user?(current_user), nil, verb: 'view', module_name: "page") do
      OpenChain::CustomHandler::Intacct::IntacctDataPusher.delay.run_schedulable companies: ['vfc', 'lmd', 'vcu', 'als']

      add_flash :notices, "All Accounting data loaded into VFI Track without errors will be pushed to Intacct shortly."
      redirect_to action: "index"
    end
  end

  def self.allowed_user? user
    g = Group.use_system_group VFI_ACCOUNTING_USERS, "Intacct Accounting"
    (Rails.env.development? || MasterSetup.get.system_code=='www-vfitrack-net') && user.in_group?(g)
  end

end
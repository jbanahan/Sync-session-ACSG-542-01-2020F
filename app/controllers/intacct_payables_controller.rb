class IntacctPayablesController < ApplicationController

  def index
    action_secure(IntacctReceivablesController.allowed_user?(current_user), nil, verb: 'view', module_name: "Payable") do
      @errors = IntacctPayable.where(intacct_key: nil).where("intacct_errors IS NOT NULL")
    end
  end

  def clear
    action_secure(IntacctReceivablesController.allowed_user?(current_user), nil, verb: 'view', module_name: "Payable") do
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

end
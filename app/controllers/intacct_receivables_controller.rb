class IntacctReceivablesController < ApplicationController

  def index
    action_secure(IntacctReceivablesController.allowed_user?(current_user), nil, verb: 'view', module_name: "Receivable") do
      @errors = IntacctReceivable.where(intacct_key: nil).where("intacct_errors IS NOT NULL")
    end
  end

  def clear
    action_secure(IntacctReceivablesController.allowed_user?(current_user), nil, verb: 'view', module_name: "Receivable") do
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

  def self.allowed_user? user
    # Ideally, we'd have some form of system group that would allow us to tie users together to form 
    # an 'accounting' group and allow them access...we don't.
    (Rails.env.development? || MasterSetup.get.system_code=='www-vfitrack-net') && ["Luca", "ivalcarcel", "jhulford", "bglick"].include?(user.username)
  end

end
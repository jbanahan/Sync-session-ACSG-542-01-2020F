class RandomAuditsController < ApplicationController

  def download
    audit = RandomAudit.find params[:id]
    action_secure(audit.can_view?(current_user), audit, {:verb=>"download",:module_name=>"random audit",:lock_check=>false}) {
      redirect_to audit.secure_url
    }
  end

end

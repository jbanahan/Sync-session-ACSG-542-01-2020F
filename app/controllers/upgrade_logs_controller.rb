class UpgradeLogsController < ApplicationController

  def show
    sys_admin_secure("Only sys admins can view upgrade logs.") {
      @upgrade_log = UpgradeLog.find params[:id]
    }
  end

end

class MasterSetupsController < ApplicationController
  def index
    redirect_to edit_master_setup_path MasterSetup.first
  end

  def edit
    sys_admin_secure("Only sys admins can edit the master setup.") {
      @ms = MasterSetup.first
    }
  end

  def update
    sys_admin_secure("Only sys admins can edit the master setup.") {
      m = MasterSetup.first
      add_flash :notices, "Master setup updated successfully." if m.update_attributes(params[:master_setup])
      errors_to_flash m
      redirect_to edit_master_setup_path m
    }
  end

end

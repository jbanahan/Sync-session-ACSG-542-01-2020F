class MasterSetupsController < ApplicationController
  def index
    redirect_to edit_master_setup_path MasterSetup.get
  end

  def edit
    sys_admin_secure("Only sys admins can edit the master setup.") {
      @ms = MasterSetup.get
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

  def show_system_message
    admin_secure("Only administrators can work with the system message.") {
    
    } 
  end

  def set_system_message
    admin_secure("Only administrators can set the system message.") {
      m = MasterSetup.get
      m.system_message = params[:system_message]
      add_flash :notices, "System message updated successfully." if m.save
      errors_to_flash m
      redirect_to show_system_message_master_setups_path
    }
  end

  def upgrade
    sys_admin_secure("Only system administrators can run upgrades.") {
      if params[:name].blank?
        add_flash :errors, "You must specify a version name for the upgrade."
      else
        MasterSetup.get.update_attributes(:target_version=>params[:name])
        add_flash :notices, "Upgrade to version #{params[:name]} initiated."
      end
      redirect_to edit_master_setup_path MasterSetup.get 
    }
  end

end

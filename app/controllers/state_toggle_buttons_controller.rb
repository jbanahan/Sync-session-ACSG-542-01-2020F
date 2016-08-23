class StateToggleButtonsController < ApplicationController
  def index
    sys_admin_secure { 
      @buttons = StateToggleButton.all.map do |stb| 
        user_field = stb.user_attribute ? ModelField.find_by_uid(stb.user_attribute.to_sym).label : stb.user_custom_definition.try(:label)
        date_field = stb.date_attribute ? ModelField.find_by_uid(stb.date_attribute.to_sym).label : stb.date_custom_definition.try(:label)
        {stb: stb, user_field: user_field, date_field: date_field}
      end
    }
  end

  def new
    sys_admin_secure { 
      @button = StateToggleButton.new
      @cm_list = CoreModule.all.map{ |cm| cm.class_name }.sort 
    }
  end

  def edit
    sys_admin_secure { render :edit }
  end

  def create
    sys_admin_secure {
      button = StateToggleButton.create!(module_type: params[:module_type], permission_group_system_codes: "PLACEHOLDER")  #prevents stb from being activated before remaining fields are supplied
      redirect_to edit_state_toggle_button_path(button)
    }
  end

  def destroy
    sys_admin_secure { 
      StateToggleButton.find(params[:id]).destroy
      redirect_to state_toggle_buttons_path
    }
  end
end
class StateToggleButtonsController < ApplicationController
  def set_page_title
    @page_title = 'Tools'
  end

  def index
    admin_secure do
      @buttons = StateToggleButton.order("module_type ASC, display_index ASC, id ASC").map do |stb|
        user_field = stb.user_field.try(:label)
        date_field = stb.date_field.try(:label)
        {stb: stb, user_field: user_field, date_field: date_field}
      end
    end
  end

  def new
    admin_secure do
      @button = StateToggleButton.new
      @cm_list = CoreModule.all.map(&:class_name).sort
    end
  end

  def edit
    admin_secure { render :edit }
  end

  def create
    admin_secure do
      button = StateToggleButton.create!(module_type: params[:module_type], disabled: true)  # prevents stb from being activated before all fields are supplied
      redirect_to edit_state_toggle_button_path(button)
    end
  end
end

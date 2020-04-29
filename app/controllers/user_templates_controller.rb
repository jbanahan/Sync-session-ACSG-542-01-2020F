class UserTemplatesController < ApplicationController
  def set_page_title
    @page_title = 'Tools'
  end
  def index
    admin_secure do
      @user_templates = UserTemplate.order(:name)
    end
  end
  def create
    admin_secure do
      u = UserTemplate.new(params[:user_template])
      if u.save
        add_flash :notices, "Template saved."
      else
        errors_to_flash u
      end
      redirect_to user_templates_path
    end
  end
  def edit
    admin_secure do
      @user_template = UserTemplate.find(params[:id])
    end
  end
  def update
    admin_secure do
      u = UserTemplate.find(params[:id])
      if u.update_attributes(params[:user_template])
        add_flash :notices, "Template saved."
      else
        errors_to_flash u
      end
      redirect_to user_templates_path
    end
  end
  def destroy
    admin_secure do
      u = UserTemplate.find(params[:id])
      if u.destroy
        add_flash :notices, "Template deleted."
      else
        errors_to_flash u
      end
      redirect_to user_templates_path
    end
  end
end

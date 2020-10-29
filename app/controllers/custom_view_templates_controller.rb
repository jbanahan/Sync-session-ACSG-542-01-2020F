class CustomViewTemplatesController < ApplicationController
  def set_page_title
    @page_title = 'Tools'
  end

  def index
    sys_admin_secure { @templates = CustomViewTemplate.all }
  end

  def new
    sys_admin_secure do
      @template = CustomViewTemplate.new
      @cm_list = CoreModule.all.map(&:class_name).sort
    end
  end

  def create
    sys_admin_secure do
      template = CustomViewTemplate.create!(template_identifier: params[:template_identifier], template_path: params[:template_path],
                                            module_type: params[:module_type])
      redirect_to edit_custom_view_template_path(template)
    end
  end

  def edit
    sys_admin_secure { render :edit }
  end

  def destroy
    sys_admin_secure do
      CustomViewTemplate.find(params[:id]).destroy
      redirect_to custom_view_templates_path
    end
  end
end

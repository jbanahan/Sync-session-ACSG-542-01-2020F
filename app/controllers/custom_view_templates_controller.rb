class CustomViewTemplatesController < ApplicationController

  def index
    sys_admin_secure { @templates = CustomViewTemplate.all }
  end

  def new
    sys_admin_secure { 
      @template = CustomViewTemplate.new
      @cm_list = CoreModule.all.map{ |cm| cm.class_name }.sort 
    }
  end

  def create
    sys_admin_secure {
      template = CustomViewTemplate.create!(template_identifier: params[:template_identifier], template_path: params[:template_path], 
                                            module_type: params[:module_type])
      redirect_to edit_custom_view_template_path(template)
    }
  end
  
  def edit
    respond_to do |format|
      format.html do 
        sys_admin_secure { render :edit }
      end
      format.json do
        if current_user.sys_admin?
          template = CustomViewTemplate.find params[:id]
          mf_digest = get_mf_digest template
          render json: { template: template, criteria: template.search_criterions.map{ |sc| sc.json(current_user) }, model_fields: mf_digest }
        else 
          render_json_error "You are not authorized to edit this template."
        end
      end
    end
  end

  def update
    if current_user.sys_admin?
      cvt = CustomViewTemplate.find params[:id]
      new_criterions = params[:criteria]
      cvt.search_criterions.delete_all
      new_criterions.each do |sc|
        cvt.search_criterions.build :model_field_uid=>sc[:mfid], :operator=>sc[:operator], :value=>sc[:value], :include_empty=>sc[:include_empty]
      end
      cvt.save!
      render json: {ok: 'ok'}
    else
      render_json_error "You are not authorized to update this template."
    end
  end

  def destroy
    sys_admin_secure { 
      CustomViewTemplate.find(params[:id]).destroy
      redirect_to custom_view_templates_path
    }
  end

  def get_mf_digest template
    mfs = CoreModule.find_by_class_name(template.module_type).default_module_chain.model_fields.values
    ModelField.sort_by_label(mfs).collect {|mf| {:mfid=>mf.uid,:label=>mf.label,:datatype=>mf.data_type}}
  end

end
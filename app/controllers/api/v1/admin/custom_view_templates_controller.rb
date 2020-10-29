module Api; module V1; module Admin; class CustomViewTemplatesController < Api::V1::Admin::AdminApiController
  before_action :require_sys_admin

  def edit
    template = CustomViewTemplate.find params[:id]
    mf_digest = get_mf_digest template
    render json: { template: template, criteria: template.search_criterions.map { |sc| sc.json(current_user) }, model_fields: mf_digest }
  end

  def update
    params[:cvt].delete(:module_type) # ensure module_type can't be changed
    cvt = CustomViewTemplate.find params[:id]
    cvt.assign_attributes(permitted_params(params))
    new_criterions = params[:criteria] || []
    cvt.search_criterions.delete_all
    new_criterions.each do |sc|
      cvt.search_criterions.build model_field_uid: sc[:mfid], operator: sc[:operator], value: sc[:value], include_empty: sc[:include_empty]
    end
    cvt.save!
    render json: {ok: 'ok'}
  end

  def get_mf_digest template
    mfs = CoreModule.find_by(class_name: template.module_type).default_module_chain.model_fields.values
    ModelField.sort_by_label(mfs).collect {|mf| {mfid: mf.uid, label: mf.label, datatype: mf.data_type}}
  end

  def permitted_params(params)
    params.require(:cvt).permit(:template_identifier, :template_path, :module_type)
  end

end; end; end; end
module Api; module V1; module Admin; class StateToggleButtonsController < Api::V1::Admin::AdminApiController
  before_filter :require_admin
  
  def edit
    button = StateToggleButton.find params[:id]
    mf_digest = get_mf_digest button
    render json: { button: button, 
                   criteria: button.search_criterions.map{ |sc| sc.json(current_user) }, 
                   sc_mfs: mf_digest[:sc_mfs],
                   user_mfs: mf_digest[:user_mfs],
                   user_cdefs: mf_digest[:user_cdefs],
                   date_mfs: mf_digest[:date_mfs],
                   date_cdefs: mf_digest[:date_cdefs] }
  end

  def update
    if params[:stb][:user_attribute] && params[:stb][:user_custom_definition_id] || params[:stb][:date_attribute] && params[:stb][:date_custom_definition_id]
      render_error "You cannot set both date/user fields at the same time.", 400
      return
    end
    stb = StateToggleButton.find params[:id]
    params[:stb].delete(:module_type) # module_type not updateable
    toggle_field(stb, params[:stb])
    stb.update_attributes(params[:stb])
    new_criterions = params[:criteria] || []
    stb.search_criterions.delete_all
    new_criterions.each do |sc|
      stb.search_criterions.build :model_field_uid=>sc[:mfid], :operator=>sc[:operator], :value=>sc[:value], :include_empty=>sc[:include_empty]
    end
    stb.save!
    render json: {ok: 'ok'}
  end

  def destroy
    StateToggleButton.find(params[:id]).destroy
    render json: {ok: 'ok'}
  end

  def get_mf_digest stb
    user_mfs, date_mfs = get_user_and_date_mfs(stb)
    user_cdefs, date_cdefs = get_user_and_date_cdefs(stb)
    {sc_mfs: get_sc_mfs(stb), user_mfs: user_mfs, user_cdefs: user_cdefs, date_mfs: date_mfs, date_cdefs: date_cdefs}
  end

  def get_sc_mfs stb
    mfs = CoreModule.find_by_class_name(stb.module_type).default_module_chain.model_fields.values
    ModelField.sort_by_label(mfs).collect {|mf| {:mfid=>mf.uid,:label=>mf.label,:datatype=>mf.data_type}}
  end

  def get_user_and_date_mfs stb
    user_list, date_list = [], []
    cm = CoreModule.find_by_class_name(stb.module_type)
    cm.model_fields.each do |uid, mf| 
      user_list << {mfid: uid.to_s, label: mf.label}
      date_list << {mfid: uid.to_s, label: mf.label} if mf.data_type == :datetime
    end
    [user_list, date_list]
  end

  def get_user_and_date_cdefs stb
    user_list, date_list = [], []
    all = CustomDefinition.where(module_type: stb.module_type)
    all.each do |cdef|
      user_list << {cdef_id: cdef.id, label: cdef.label} if cdef.is_user?
      date_list << {cdef_id: cdef.id, label: cdef.label} if cdef.data_type == "datetime"
    end
    [user_list, date_list]
  end

  #ensure setting an mf sets cdef to nil and vice versa
  def toggle_field stb, stb_hsh
    if stb.user_attribute && stb_hsh[:user_custom_definition_id]
      stb_hsh[:user_attribute] = nil
    elsif stb.user_custom_definition_id && stb_hsh[:user_attribute]
      stb_hsh[:user_custom_definition_id] = nil
    end

    if stb.date_attribute && stb_hsh[:date_custom_definition_id]
      stb_hsh[:date_attribute] = nil
    elsif stb.date_custom_definition_id && stb_hsh[:date_attribute]
      stb_hsh[:date_custom_definition_id] = nil
    end
  end

end; end; end; end
#relies on implementing controller having access to find_object_by_id method
module Api; module V1; module StateToggleSupport
  def toggle_state_button
    obj = find_object_by_id params[:id]
    button_id = params[:button_id].to_s.to_i
    btn = nil
    StateToggleButton.for_core_object_user(obj,current_user).each do |b|
      if b.id == button_id
        btn = b
        break
      end
    end
    raise StatusableError.new("Button not accessible at this time.",:forbidden) unless btn
    btn.async_toggle! obj, current_user
    render json: {'ok'=>'ok'}
  end

  def state_toggle_buttons
    obj = find_object_by_id params[:id]
    render json: {state_toggle_buttons:render_state_toggle_buttons(obj,current_user)}
  end

  #helper method for injecting buttons into other API calls
  def render_state_toggle_buttons obj, user
    r = []
    StateToggleButton.for_core_object_user(obj,user).each do |b|
      path = CoreModule.find_by_object(obj).class_name.tableize
      show_activate = b.to_be_activated?(obj)
      btn_text = show_activate ? b.activate_text : b.deactivate_text
      btn_confirmation = show_activate ? b.activate_confirmation_text : b.deactivate_confirmation_text
      r << {id:b.id,button_text:btn_text,button_confirmation:btn_confirmation,
        core_module_path:path,base_object_id:obj.id
      }
    end
    r
  end
end; end; end

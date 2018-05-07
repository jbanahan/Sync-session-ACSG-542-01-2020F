require 'open_chain/api/v1/core_module_api_json_support'

#relies on implementing controller having access to find_object_by_id method
module Api; module V1; module StateToggleSupport
  include OpenChain::Api::V1::CoreModuleApiJsonSupport # provides the render method

  def toggle_state_button
    obj = find_object_by_id params[:id]

    button_id = nil
    button_identifier = nil

    if params[:button_id].to_s.to_i != 0
      button_id = params[:button_id].to_s.to_i
    elsif !params[:identifier].blank?
      button_identifier = params[:identifier].strip
    end

    btn = nil
    StateToggleButton.for_core_object_user(obj,current_user).each do |b|
      if (button_id && b.id == button_id) || (button_identifier && b.identifier == button_identifier)
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
    json = {}

    render json: render_state_toggle_buttons(obj, current_user, api_hash: json)
  end

end; end; end

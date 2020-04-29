module OpenChain; module Api; module V1; module CoreModuleApiJsonSupport
  extend ActiveSupport::Concern

  def render_state_toggle_buttons? params
    params[:include].to_s.include? "state_toggle_buttons"
  end

  # Returns a json rendering of the active state toggle buttons the user can access.
  # Optionally, if api_hash is passed, it will render the buttons directly into the hash under the 'state_toggle_buttons' key
  # Optionally, if params is passed, it will check if 'state_toggle_buttons' were requested in the 'includes' parameter
  def render_state_toggle_buttons obj, user, api_hash: nil, params: nil
    buttons = []
    if params.nil? || render_state_toggle_buttons?(params)
      api_hash[:state_toggle_buttons] = buttons unless api_hash.nil?

      StateToggleButton.for_core_object_user(obj , user).each do |b|
        path = CoreModule.find_by_object(obj).class_name.tableize
        show_activate = b.to_be_activated?(obj)
        btn_text = show_activate ? b.activate_text : b.deactivate_text
        btn_confirmation = show_activate ? b.activate_confirmation_text : b.deactivate_confirmation_text
        buttons << {id:b.id, button_text:btn_text, button_confirmation:btn_confirmation,
          core_module_path:path, base_object_id:obj.id, simple_button: b.simple_button?, identifier: b.identifier, display_index: b.display_index
        }
      end
    end

    buttons
  end

end; end; end; end;
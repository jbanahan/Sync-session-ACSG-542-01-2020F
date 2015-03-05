root = exports ? this
root.ChainStateButtons = {
  getButtons: (coreModulePath,objId) ->
    $.ajax {
      url: '/api/v1/'+coreModulePath+'/'+objId+'/state_toggle_buttons.json'
      contentType: 'application/json'
      type: 'GET'
      dataType: 'json'
    }

  toggleButton: (coreModulePath,objId,buttonId) ->
    $.ajax {
      url: '/api/v1/'+coreModulePath+'/'+objId+'/toggle_state_button.json'
      method: 'POST'
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json"
      }
      data: JSON.stringify({button_id: buttonId})
    }

  buttonClickHandler: (evt) ->
    $('[data-state-toggle-id]').prop('disabled',true) #disable button to prevent multiple state changes
    btn = $(evt.target)
    coreModulePath = btn.attr('data-core-module-path')
    objId = btn.attr('data-object-id')
    buttonId = btn.attr('data-state-toggle-id')
    confirmationMsg = btn.attr('data-confirmation')
    if confirmationMsg && window.confirm(confirmationMsg)
      ChainStateButtons.toggleButton(coreModulePath,objId,buttonId).done (data) ->
        location.reload(true)

  injectButtons: (outer,buttons) ->
    $(outer).find('[data-state-toggle-id]').remove()
    for btn in buttons
      confAttr = if btn.button_confirmation then "data-confirmation='"+btn.button_confirmation+"'" else ""
      outer.append("<button class='btn btn-default navbar-btn' data-core-module-path='"+btn.core_module_path+"' data-object-id='"+btn.base_object_id+"' data-state-toggle-id='"+btn.id+"' "+confAttr+">"+btn.button_text+"</button>")

  loadButtons: (coreModulePath,objId) ->
    outer = $('#nav-action-bar .btn-group')
    outer.append("<button class='btn btn-default navbar-btn' title='Loading more buttons' id='ChainStateButtonInit'><i class='fa fa-circle-o-notch fa-spin'></i></button>")
    ChainStateButtons.getButtons(coreModulePath,objId).done (data) ->
      $('#ChainStateButtonInit').remove()
      if data.state_toggle_buttons
        ChainStateButtons.injectButtons(outer,data.state_toggle_buttons)
      $('[data-state-toggle-id]').prop('disabled',false) #clear any disabled buttons

  initialize: (coreModulePath,objId) ->
    ChainStateButtons.loadButtons(coreModulePath,objId)
    $(document).on 'click', 'button[data-state-toggle-id]', ChainStateButtons.buttonClickHandler
}

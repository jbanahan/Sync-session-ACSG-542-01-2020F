root = exports ? this
root.UserTemplate =
  validateForm : (form) ->
    json_text = $(form).find('[name="user_template[template_json]"]').val()
    try
      JSON.parse json_text
    catch e
      window.alert "Not valid JSON."
      return false
    return true
    

root = exports ? this
root.RailsHelper =
  authToken : (val) ->
    @aToken = val if val
    @aToken

  prepRailsForm : (form,action,method) ->
    form.attr('action',action)

    h = "<div style='margin:0;padding:0;display:inline'>"
    h += "<input type='hidden' name='authenticity_token' value='"+RailsHelper.authToken()+"' />" unless method=='get'
    h += "<input type='hidden' name='utf8' value='&#x2713;'/>"
    if (method=='delete' || method=='put')
      form.attr('method','post')
      h += "<input type='hidden' name='_method' value='"+method+"' />"
    else
      form.attr('method',method)
    form.append(h)

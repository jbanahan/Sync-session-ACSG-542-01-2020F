root = exports ? this

root.ChainAllPages =

  # This method can be used to easily make an ajax request to a controller that generates a partial
  # and then render that partial back into the page.
  #
  # This can be useful for screens that have hidden content (or content that's expensive to generate)
  # and can wait until a user actually requests the data to be rendered to view it.
  #
  #
  # Request should be a javascript object ({}), that at the absolute least, must have the following
  # attributes in order to make a request:
  # requestPath -> the http endpoint for the request
  # 
  # Optional attributes:
  # target -> a jquery selector used to append the response HTML directly into
  # 
  # Ajax attributes (these all pretty much directly map to the jquery Ajax parameters)
  # ajaxMethod -> the HTTP method to use (default GET)
  # ajaxData -> Any query parameters to use
  
  renderRemote: (requestData) ->
    request = {
      url: requestData.requestPath
      method: (if requestData.ajaxMethod then requestData.ajaxMethod else "GET")
      dataType: "html"
    }
    request.headers = {}
    csrfToken = ChainAllPages.getAuthToken()
    request.headers['X-CSRF-Token'] = csrfToken if csrfToken
    request.data = request.ajaxData if requestData.ajaxData
    
    if request.url
      $.ajax(request).done((response) ->
        if requestData.target
          # This is simply a way to mark the target as having been rendered remotely
          # This can be useful in cases where we don't want the data to be rendered multiple times
          $(requestData.target).data("remotely-rendered", true)
          $(requestData.target).html(response)
      ).fail((response) ->
        if requestData.failCallback
          requestData.failCallback(response)
      )
    null

  getAuthToken : () ->
    # First check for the csrf cookie (since that's what angular uses as well), then fall back to the meta tag.
    # PhantomJs doesn't support Array.prototype.find, hence the use of filter 
    token = document.cookie?.split("; ").filter((elem) -> /^XSRF-TOKEN/.exec(elem))[0]?.split("=")[1]
    unless token
      token = $('meta[name="csrf-token"]').attr('content')
    token

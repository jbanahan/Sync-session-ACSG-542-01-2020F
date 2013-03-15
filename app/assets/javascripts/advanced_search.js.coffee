root = exports ? this
root.OCAdvancedSearch =
  
  currentPage : 1

  #get the result rows html from the server and pass to callback
  getResultRows : (searchId,page,callback) ->
    url = '/advanced_search/'+searchId+'/result?page='+page
    jQuery.get url, (data) ->
      callback data

  replaceResultRows : (tbody,searchId,page) ->
    $(tbody).html("<tr><td colspan='100%'>Loading results...</td></tr>")
    @.getResultRows searchId, page, (data) ->
      $(tbody).html(data)
      @.currentPage = page

  loadPagination : (wrapper,searchId) ->
    jQuery.get '/advanced_search/'+searchId+'/count', (totalItems) ->
      totalPages = (totalItems/100) + (if totalItems % 100 == 0 then 0 else 1)
      totalPages = 1 if totalPages == 0
      h = ""
      for pNum in [1..totalPages]
        h += "<span><a href='#' data-action='replaceResults' page='"+pNum+">"+pNum+"</a></span>"
      $(wrapper).html h

  loadInitialRows : (tbody,searchId) ->
    @replaceResultRows tbody, searchId, 1

root = exports ? this
root.OCQuickSearch =
  byModule: (moduleType,val) ->
    $.getJSON('/quick_search/by_module/'+moduleType+'?v='+encodeURIComponent(val),OCQuickSearch.writeModuleResponse)

  writeModuleResponse: (jsonData) ->
    qs = jsonData.qs_result
    html = ''
    if qs.vals.length == 10
      html += "<div class='alert alert-warning' role='alert'>Only the first 10 results are shown.</div>"
    html += OCQuickSearch.makeCard(qs.fields,obj,qs.search_term) for obj in qs.vals

    html = '<div class="text-muted">No results found for this search.</div>' if html == ''

    OCQuickSearch.findDivWrapper(qs.module_type).html(html)

  findDivWrapper: (moduleType) ->
    $('#modwrap_'+moduleType)

  makeCard: (fields, obj, searchTerm) ->
    getHtmlVal = (val, searchTerm) ->
      highlightVal = (str, startIdx, searchTerm) ->
        index = str.toLowerCase().indexOf(searchTerm.toLowerCase(),startIdx)
        r = {}
        if (index >= 0)
          r.str = str.substring(0, index) + '<mark>' + str.substring(index, index + searchTerm.length) + '</mark>'+ str.substring(index+searchTerm.length)
          r.nextIndex = index + searchTerm.length + 13 # 13 == <mark></mark> which needs to be added on so we don't research the same space
        else
          r.str = str
          r.nextIndex = -1
        return r

      highlighted = highlightVal(val, 0, searchTerm)
      # keep looping and highlighting until you get all of the instances of the search term in the value
      while highlighted.nextIndex > 0
        highlighted = highlightVal(highlighted.str, highlighted.nextIndex, searchTerm)

      return highlighted.str

    h = "<div class='panel panel-primary qs-card'>"
    fieldCounter = 0
    for id, lbl of fields
      val = obj[id]
      if val && val.length > 0
        htmlVal = getHtmlVal(val,searchTerm)
        if fieldCounter == 0
          h += "<div class='panel-heading'><h3 class='panel-title'><a href='"+obj['view_url']+"'>"+val+"</a></h3></div><table class='table table-hover'>"
        h += "<tr><td class='qs-td-label'><strong>"+lbl+":</strong></td><td>"+htmlVal+"</td></tr>"
        fieldCounter++
    h += "</table>"
    h += "<div class='panel-footer text-right'><a href='"+obj['view_url']+"' class='btn btn-sm btn-default'><i class='fa fa-link'></i></a></div>"
    h += "</div>"
    h
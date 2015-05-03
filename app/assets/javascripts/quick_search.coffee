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
    h = "<div class='panel panel-primary qs-card'>"
    fieldCounter = 0
    for id, lbl of fields
      val = obj[id]
      if val && val.length > 0
        htmlVal = val.replace(searchTerm,"<mark>"+searchTerm+"</mark>")
        if fieldCounter == 0
          h += "<div class='panel-heading'><h3 class='panel-title'><a href='"+obj['view_url']+"'>"+val+"</a></h3></div><table class='table table-hover'>"
        h += "<tr><td class='qs-td-label'><strong>"+lbl+":</strong></td><td>"+htmlVal+"</td></tr>"
        fieldCounter++
    h += "</table>"
    h += "<div class='panel-footer text-right'><a href='"+obj['view_url']+"' class='btn btn-sm btn-default'><i class='fa fa-link'></i></a></div>"
    h += "</div>"
    h
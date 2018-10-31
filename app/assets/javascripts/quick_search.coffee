root = exports ? this
root.OCQuickSearch =
  byModule: (moduleType,val) ->
    $.getJSON('/quick_search/by_module/'+moduleType+'?v='+encodeURIComponent(val),OCQuickSearch.writeModuleResponse)

  writeModuleResponse: (jsonData) ->
    qs = jsonData.qs_result
    html = ''
    if qs.vals.length == 10
      html += "<div class='alert alert-warning' role='alert'>Only the first 10 results are shown. For more results, please run a <a href='/#{jsonData.qs_result.adv_search_path}'>full search</a>.</div>"
    html += OCQuickSearch.makeCard(qs.fields,obj,qs.extra_fields,qs.extra_vals,qs.search_term) for obj, idx in qs.vals

    html = '<div class="text-muted">No results found for this search.</div>' if html == ''

    OCQuickSearch.findDivWrapper(qs.module_type).html(html)

  findDivWrapper: (moduleType) ->
    $('#modwrap_'+moduleType)

  
  makeCard: (fields, obj, extraFields, extraVals, searchTerm) ->

    cardHeader = () ->
      "<div class='card qs-card'>"

    cardFooter = () ->
      "</div>"

    resultRow = (label, value) ->
      "<tr><td class='qs-td-label' scope='row'><strong>"+label+":</strong></td><td>"+value+"</td></tr>"

    headerRow = (url, value) ->
      "<div class='card-header'><div class='float-left'><a href='"+url+"'>"+value+"</a></div><div class='float-right'><a href='"+url+"'><i class='fa fa-link'></i></a></div></div>"

    dividerRow = () ->
      "<tr class='divider'><td><small>More Info</small></td><td></td></tr>"

    resultsHeader = () ->
      "<table class='table table-hover'>"

    resultsFooter = () ->
      "</table>"

    cardContent = (obj, fields, extraFields, extraVals, searchTerm) ->
      html = showSearchFields(fields, obj, searchTerm)
      if html != ''
        html += showExtraFields(extraFields, extraVals, obj)
        html += resultsFooter()

      html

    showSearchFields = (fields, obj, searchTerm) ->   
      fieldCounter = 0
      html = ""
      for id, lbl of fields
        val = obj[id]
        if val && val.length > 0
          if fieldCounter == 0
            html += headerRow(obj['view_url'], val)
            html += resultsHeader()
          html += resultRow(lbl, getHtmlVal(val,searchTerm))
          fieldCounter++
      html
    
    showExtraFields = (extraFields, extraVals, obj) ->
      hasExtraVals = (ev) ->
        for k,v of ev
            return true if !!v
        false
      html = ""
      extraValsForObj = extraVals[obj.id]
      if hasExtraVals extraValsForObj
        html = dividerRow()
        for id, lbl of extraFields
          val = extraValsForObj[id]
          if !!val
            html += resultRow(lbl, val)
      html
      
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

    h = cardHeader()
    h += cardContent(obj, fields, extraFields, extraVals, searchTerm)
    h += cardFooter()

root = exports ? this
root.OCQuickSearch =
  byModule: (moduleType,val) ->
    $.getJSON('/quick_search/by_module/'+moduleType+'?v='+encodeURIComponent(val),OCQuickSearch.writeModuleResponse)

  writeModuleResponse: (jsonData,status,request,newTab) ->
    qs = jsonData.qs_result
    html = ''
    if qs.vals.length == 10
      html += "<div class='alert alert-warning' role='alert'>Only the first 10 results are shown. For more results, please run a <a href='/#{jsonData.qs_result.adv_search_path}'>full search</a>.</div>"
    for obj, idx in qs.vals
      html += OCQuickSearch.makeCard(qs.fields,obj,qs.extra_fields,qs.extra_vals,qs.attachments,qs.business_validation_results,qs.search_term,newTab)

    html = '<div class="text-muted">No results found for this search.</div>' if html == ''

    OCQuickSearch.findDivWrapper(qs.module_type).html(html)

  findDivWrapper: (moduleType) ->
    $('#modwrap_'+moduleType)

  
  makeCard: (fields, obj, extraFields, extraVals, attachments, businessValidations, searchTerm, newTab) ->

    cardHeader = () ->
      "<div class='card qs-card'>"

    cardFooter = () ->
      "</div>"

    attachmentIcon = (a) ->
      iconsAvailable = {
        doc:'fa-file-word-o',docx:'fa-file-word-o',docm:'fa-file-word-o',
        odt:'fa-file-word-o',xls:'fa-table',xlsx:'fa-table',csv:'fa-table',
        xlsm:'fa-table',ods:'fa-table',ppt:'fa-file-powerpoint-o',
        pptx:'fa-file-powerpoint-o',pptm:'fa-file-powerpoint-o',
        odp:'fa-file-powerpoint-o',pdf:'fa-file-pdf-o'}

      icon = 'fa-file-text'
      if RegExp("image").test(a.content_type)
        icon = 'fa-picture-o'

      if a.name.split('.').pop().toLowerCase() of iconsAvailable == true
        icon = iconsAvailable[a.name.split('.').pop().toLowerCase()]

      icon

    businessValidationBuilder = (b) ->
      bus = document.createElement("A")
      icon = document.createElement("I")

      bus.setAttribute('class', 'btn-link')
      bus.setAttribute('href', b.validation_link)
      status = document.createTextNode(b.state)
      space = document.createTextNode(" ")

      if b.state == 'Fail'
        icon.setAttribute('class', 'fa fa-medkit text-danger fa-lg')
      else if b.state == 'Review'
        icon.setAttribute('class', 'fa fa-medkit text-warning fa-lg')
      else if b.state == 'Pass'
        icon.setAttribute('class', 'fa fa-medkit text-success fa-lg')
      else
        icon.setAttribute('class', 'fa fa-medkit text-secondary fa-lg')

      bus.appendChild(icon)
      bus.appendChild(space)
      bus.appendChild(status)

      bus.outerHTML

    attachmentBuilder = (a) ->
      label = document.createTextNode(a.type + ' - ' + a.name)
      if (a.type + ' - ' + a.name).length > 13
        smlabel = document.createTextNode((' ' + a.type + ' - ' + a.name).substring(0, 11) + '...' )
      else
        smlabel = ' ' + label.textContent

      att = document.createElement('a')
      att.setAttribute('href', a.download_link)
      att.setAttribute('title', label.textContent)
      att.setAttribute('class', 'btn btn-outline-dark mr-1 mt-1')
      att.setAttribute('target', '_blank')
      
      icon = document.createElement('i')
      icon.setAttribute('class', 'fa '+attachmentIcon(a)+' fa-lg')
      att.appendChild(icon)
      att.appendChild(smlabel)
      att.outerHTML

    resultRow = (label, value) ->
      "<tr><td class='qs-td-label' scope='row'><strong>"+label+":</strong></td><td>"+value+"</td></tr>"

    headerRow = (url, value, newTab) ->
      target = if newTab then "_blank" else "_self"
      "<div class='card-header'><div class='float-left'><a href='#{url}' target='#{target}'>#{value}</a></div><div class='float-right'><a href='#{url}' target='#{target}'><i class='fa fa-link'></i></a></div></div>"

    dividerRow = () ->
      "<tr class='divider'><td><small>More Info</small></td><td></td></tr>"

    resultsHeader = () ->
      "<table class='table table-hover'>"

    resultsFooter = () ->
      "</table>"

    cardContent = (obj, fields, extraFields, extraVals, attachments, businessValidations, searchTerm, newTab) ->
      html = showSearchFields(fields, obj, searchTerm, newTab)
      if html != ''
        html += showExtraFields(extraFields, extraVals, attachments, businessValidations, obj)
        html += resultsFooter()

      html

    showSearchFields = (fields, obj, searchTerm, newTab) ->   
      fieldCounter = 0
      html = ""
      for id, lbl of fields
        val = obj[id]
        if val && val.length > 0
          if fieldCounter == 0
            html += headerRow(obj['view_url'], val, newTab)
            html += resultsHeader()
          html += resultRow(lbl, getHtmlVal(val,searchTerm))
          fieldCounter++
      html
    
    showExtraFields = (extraFields, extraVals, attachments, businessValidations, obj) ->
      hasExtraVals = (ev) ->
        for k,v of ev
            return true if !!v
        false
      html = ""
      
      extraValsForObj = extraVals[obj.id]
      
      if hasExtraVals(attachments[obj.id]) or hasExtraVals(extraValsForObj) or hasExtraVals(businessValidations[obj.id])
        html = dividerRow()

      attValsForObj = attachments[obj.id]
      if hasExtraVals attValsForObj
        i = 0
        attlist = ""
        while i < attValsForObj.length
          attlist += attachmentBuilder(attValsForObj[i])
          i++
        html += resultRow("Attachments", attlist)

      busValsForObj = businessValidations[obj.id]
      if hasExtraVals busValsForObj
        html += resultRow("Business Rule State", businessValidationBuilder(busValsForObj))

      if hasExtraVals extraValsForObj
        for id, label of extraFields
          val = extraValsForObj[id]
          if !!val
            html += resultRow(label, val)
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
    h += cardContent(obj, fields, extraFields, extraVals, attachments, businessValidations, searchTerm, newTab)
    h += cardFooter()

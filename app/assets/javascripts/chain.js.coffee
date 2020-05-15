root = exports ? this
root.Chain =

  # This method is used to create a standard jQuery dialog box with key attributes set to be used everywhere
  jqueryDialog: (dialogbox, options) ->
    if !options['maxWidth']?
      options['maxWidth'] = $(window).width() * 0.90
    if !options['maxHeight']?
      options['maxHeight'] = $(window).height() * 0.90
    dialogbox.dialog(options)

  processInfiniteSelectLoad: (targetTableSelector) ->
    targetTable = $(targetTableSelector)
    url = targetTable.attr('data-infinite-table-src')
    page = targetTable.attr('data-infinite-table-page')

    if page==undefined || page.length == 0
      page = 2
    else
      page = parseInt(page) + 1

    queryParams = {page:page}
    $('[data-infinite-table-filter="'+targetTableSelector+'"]').each () ->
      val = $(this).val()
      if val.length > 0
        queryParams[$(this).attr('data-infinite-table-param')] = val

    if url
      $.ajax {
        method: 'get'
        url: url
        data: queryParams
        success: (data) ->
          targetTable.attr('data-infinite-table-page',page)
          loadMore = $('button[data-infinite-table-target="'+targetTableSelector+'"]')
          if data.match(/last-row/)
            loadMore.hide()
          else
            loadMore.show()

          targetTable.find('tbody').append(data)
      }

  processInfiniteSelectReset: (targetTableSelector) ->
    $(targetTableSelector+' tbody').html('')
    targetTable = $(targetTableSelector)
    targetTable.attr('data-infinite-table-page','0')
    Chain.processInfiniteSelectLoad(targetTableSelector)

  # pass in a selector for a multi select enabled select box and
  # this method will call the callback passing in an Array of objects with
  # val and label attributes
  multiSelect: (selectBoxSelector,callback) ->
    fullSelector = selectBoxSelector+" option:selected"
    a = $.map $.makeArray($(fullSelector)), (obj,idx) ->
      o = $(obj)
      {val:o.val(),label:o.html()}
    callback a

  getMessageCount : (url) ->
    $.getJSON url, (data) ->
      if data > 0
        $('.message_envelope').each () ->
          $(this).html(''+data).addClass('messages')
      else
        $('.message_envelope').each () ->
          $(this).html('').removeClass('messages')

  # If pollingSeconds is <=0, no ongoing polling is done.
  initialize : (user_id, pollingSeconds) ->
    @url = '/messages/message_count?user_id='+user_id

    $(document).ready () =>
      @initNotificationCenter()
      @getMessageCount(@url)
      if pollingSeconds > 0
        @startPolling(pollingSeconds)

  # runs the onwindowunload properly handling IE duplicate call issues
  # expects passed in function to return a string if user should be prompted
  # or undefined if no prompt is needed
  onBeforeUnload: (f) ->
    root.runChainUnload = true
    enableUnload = () ->
      root.runChainUnload = true

    disableUnload = () ->
      root.runChainUnload = false
      setTimeout enableUnload, 100

    window.onbeforeunload = () ->
      if root.runChainUnload
        r = f()
        disableUnload()
        return r

  # add pagination widget to target
  # currently, baseUrl cannot have other querystring parameters, but this
  # can be added pretty easily if needed in the future
  addPagination: (target,baseUrl,currentPage,totalPages) ->
    t = $(target)
    h = ''
    h += '<a class="btn btn-secondary" href="'+baseUrl+'?page=1" role="button">&lt;&lt;</a>' unless currentPage==1
    h += '<a class="btn btn-secondary" href="'+baseUrl+'?page='+(currentPage-1)+'" role="button">&lt;</a>' unless currentPage==1
    h += '<select class="pagechanger btn btn-secondary">'
    h += '<option value="'+n+'"'+(if n==currentPage then ' selected="selected"' else '')+'>'+n+'</option>' for n in [1..totalPages]
    h += '</select>'
    h += '<a class="btn btn-secondary" href="'+baseUrl+'?page='+(currentPage+1)+'" role="button">&gt;</a>' unless currentPage==totalPages
    h += '<a class="btn btn-secondary" href="'+baseUrl+'?page='+totalPages+'" role="button">&gt;&gt;</a>' unless currentPage==totalPages
    t.html h
    $('select.pagechanger').on 'change', () ->
      window.location = baseUrl+'?page='+$(this).val()

  # generates html string for a bootstrap error panel
  makeAlertPanel: (messages, needs_container = true) ->
    Chain.makePanel messages, "alert", needs_container

  makeErrorPanel: (messages, needs_container = true) ->
    Chain.makePanel messages, "error", needs_container

  makeSuccessPanel: (messages, needs_container = true) ->
    Chain.makePanel messages, "success", needs_container

  makePanel: (messages, type, needs_container) ->
    inner = messages
    if $.isArray(messages) and messages.length > 1
      inner = "<ul>"
      messages.forEach (msg) -> inner += "<li>" + msg + "</li>"
      inner += "</ul>"
    if type == "success"
      outer = "<div class='alert alert-success alert-dismissible fade show role='alert'><h4 class='alert-heading'>Success!</h4><hr><i class='fa fa-thumbs-up fa-2x'></i>&nbsp; #{inner} <button type='button' class='close' data-dismiss='alert' aria-label='Close'><span aria-hidden='true'>&times;</span></div>"
    else if type == "error"
      outer = "<div class='alert alert-danger alert-dismissible fade show' role='alert'><h4 class='alert-heading'>Error</h4><hr><i class='fa fa-warning fa-2x'></i>&nbsp; #{inner} <button type='button' class='close' data-dismiss='alert' aria-label='Close'><span aria-hidden='true'>&times;</span></div>"
    else
      outer = "<div class='alert alert-info alert-dismissible fade show' role='alert'><i class='fa fa-question-circle fa-2x'></i>&nbsp; #{inner} <button type='button' class='close' data-dismiss='alert' aria-label='Close'><span aria-hidden='true'>&times;</span></div>"
    if needs_container
      outer = "<div class='container'>#{outer}</div>"
    outer

  setStorageItem: (name, value) ->
    if (typeof(Storage) == undefined)
      return null
    else
      localStorage.setItem(name, JSON.stringify(value))

  getStorageItem: (name) ->
    if (typeof(Storage) == undefined)
      return null
    else
      return JSON.parse(localStorage.getItem(name))

  sendEmailAttachments: (controller_name, id, to_address, email_subject, email_body, ids_to_include) ->
    return $.post ('/attachments/email_attachable/' + controller_name + '/' + id),
      to_address: to_address
      email_subject: email_subject
      email_body: email_body
      ids_to_include: ids_to_include

  #tell the server never to show this user message to the current user again
  hideMessage : (messageName) ->
    $.post('/users/hide_message', {message_name: messageName})

  #populates the user list from json result
  populateUserList : (selectBox,defaultSelection,data) ->
    selectBox.html('')
    userHtml = (userData) ->
      "<option value='"+userData.id+"' " + (if userData.id==defaultSelection then "selected='selected'" else "") + ">"+userData.full_name+"</option>"
    writeCompany = (c) ->
      h = "<optgroup label='"+c.name+"'>"
      h += userHtml(u) for u in c.users
      h += "</optgroup>"
      selectBox.append(h)
    writeCompany c.company for c in data

  #load user list from ajax callback (default url is /users.json)
  loadUserList : (selectBox,defaultSelection,callback, url='/users.json') ->
    $.ajax({
      url: url
      contentType: 'application/json'
      type: 'GET'
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json"
      }
    })
    .done (data) ->
      Chain.populateUserList selectBox, defaultSelection, data
      callback(selectBox) if callback

  #
  # Tariff Classification Mangaement Stuff
  #

  htsAutoComplete : (fieldSelector) ->
    $(fieldSelector).each((inp) ->
      return if $(@).is(':data(autocomplete)')
      country = $(@).attr('country')
      $(@).autocomplete({
        source:(req,add) ->
          $.getJSON("/official_tariffs/auto_complete?country=#{country}&hts=#{req.term}&description=true", (data) ->
            r = []
            r.push(h) for h in data
            add(r)
          )
        select: (event,ui) ->
          $(@).val(ui.item.label)
          $(@).blur()

        # Needed to prevent the drop-down from stretching/breaking the bottom of the modal
        # The modal's outermost div is automatically generated, hence this less-than-ideal selector
        appendTo: "[aria-describedby='mod_quick_classify']"
      }).autocomplete("instance")._renderItem = (ul, item) ->
          $("ul").addClass("autocomplete-list")
          $("<li>").append("<div>#{item.label}<br>#{item.desc}</div>").appendTo(ul)
    )

  #load auto classification values an populate into containers that match destination_selector and also have country='[country_id]'
  loadAutoClassifications : (hts,tariff_line_num,source_country_id,destination_country_ids,destination_selector) ->
    cleanHTS = hts.replace( /[^\dA-Za-z]/g, "" )
    jQuery.get '/official_tariffs/auto_classify/'+cleanHTS+'.json', (data) ->
      Chain.populateAutoClassifications destination_selector, tariff_line_num, source_country_id, destination_country_ids, data

  writeAutoClassificationOptions : (destination_selector,country_result,tariff_line_num) ->
    h = ""
    target = $(destination_selector+"[country='#{country_result.country_id}'][tariff-line-num='#{tariff_line_num}']")
    if target.length == 0
      classi = Chain.quickClassifyProduct.classifications.find (cl) -> cl.country_id == country_result.country_id
      Chain.insertQuickClassifyTariff classi, {line_number: tariff_line_num}, "div[quick-class-content-id='#{country_result.country_id}'] div.hts-tab"
      target = $(target.selector)
    h +="<div class='auto-class-title'>Auto Classifications</div>"
    for hts in country_result['hts']
      h += "<div class='auto-class-container'><a href='#' class='hts_option'>"+hts.code+"</a>"
      h += "&nbsp;<span class='badge badge-info' title='This tariff number is used about "+numberWithCommas(hts.use_count)+" times.' data-toggle='tooltip'>"+abbrNum(hts.use_count,2)+"</span>" if hts.use_count
      h += "&nbsp;<a href='#' class='lnk_tariff_popup btn btn-secondary btn-sm' iso='"+country_result.iso+"' hts='"+hts.code+"'>info</a>"
      h += "<br />"+hts.desc+"<br />"+"Common Rate: "+hts.rate+"<br />"
      h += "</div>"
    target.find("*").remove()
    target.append(h)

  #fill the countries that match the destination_selectors with the classification date
  populateAutoClassifications : (destination_selector,tariff_line_num,source_country_id,destination_country_ids,data) ->
    write = (country_result) ->
      Chain.writeAutoClassificationOptions destination_selector, country_result, tariff_line_num
      quickClassSel = $("div.quick_class_country[country_id='#{country_result.country_id}'] i")
      inputSel = $(".hts_cell").find("input.hts_field[country='#{country_result.country_id}'][tariff-line-num=#{tariff_line_num}]")
      Chain.htsAutoComplete inputSel
      $("div[quick-class-content-id='#{country_result.country_id}'] input.hts_field[tariff-line-num='#{tariff_line_num}']").each(()->
        Classify.validateHTSValue country_result.country_id, tariff_line_num, $(this)
        Chain.updateTariffList(country_result.country_id))
      if country_result['hts'].length == 1
        inputSel.val(country_result['hts'][0]['code'])
        # Ensures tariff description, 'auto-classify' button appears without additional clicks
        inputSel.val(country_result['hts'][0]['code']).blur()
        quickClassSel.removeClass('fa fa-check-circle fa-question-circle').addClass('fa fa-exclamation-triangle')
        Chain.updateTariffList(country_result.country_id)
      else if country_result['hts'].length > 1
        inputSel.val("").blur()
        quickClassSel.removeClass('fa fa-check-circle fa-exclamation-triangle').addClass('fa fa-question-circle')

    for cntry in data
      if cntry.country_id == source_country_id
        # only write the options; don't update icons or overwrite HTS for the source country
        Chain.writeAutoClassificationOptions destination_selector, cntry, tariff_line_num
      else
        continue if cntry.country_id not in destination_country_ids
        # don't auto-classify any country with an invalid HTS
        write cntry unless $("div.quick_class_country[country_id='#{cntry.country_id}'] i").hasClass("fa-times-circle")

  #add callback that will be fired if user enters a tariff number that results in the given state
  #state options are "valid", "invalid", "empty"
  addTariffValidationCallback : (state,country_id,tariff_line_num,callback) ->
    @tariffCallbacks = {} unless @tariffCallbacks
    state_cb_set = @tariffCallbacks[state]
    if !state_cb_set
      state_cb_set = {}
      @tariffCallbacks[state] = state_cb_set
    country_cb_set = state_cb_set[country_id]
    if !country_cb_set
      country_cb_set = {}
      state_cb_set[country_id] = country_cb_set
    tariff_cb = country_cb_set[tariff_line_num]
    if !tariff_cb
      tariff_cb = []
      country_cb_set[tariff_line_num] = tariff_cb
    tariff_cb.push callback

  #fire these callbacks when a tariff field is flagged as valid
  fireTariffValidationCallbacks : (state,country_id,tariff_line_num,bad_tariff_num) ->
    return unless @tariffCallbacks
    @tariffCallbacks = {} unless @tariffCallbacks
    state_cb_set = @tariffCallbacks[state]
    return unless state_cb_set
    country_cb_set = state_cb_set[country_id]
    return unless country_cb_set
    tariff_cb = country_cb_set[tariff_line_num]
    return unless tariff_cb
    cb(bad_tariff_num) for cb in tariff_cb
    return

  #Returns HTML for one HTS/Sched B field
  quickClassifyTariff: (classification, tariff, allowDelete) ->
    c = classification
    tariffLineNum = tariff.line_number || 1
    html = ""
    html += "<div class='tariff' tariff-line-num='#{tariffLineNum}' country='#{c.country_id}'><div>"
    html += "<div class='tariff-header'>HTS Row: #{tariffLineNum}</div>"
    html += "HTS: <input type='text' class='hts_field' country='#{c.country_id}' tariff-line-num='#{tariffLineNum}' orig-value='#{tariff.hts_1 || ''}' value='#{tariff.hts_1 || ''}' id='product_classification_attributes_#{c.country_id}_tariff_records_attributes_#{tariffLineNum}_hts_hts_1' name='product[classifications_attributes][#{c.country_id}][tariff_records_attributes][#{tariffLineNum}][hts_hts_1]' />"
    html += "&nbsp;<a href='#' class='btn btn-sm btn-secondary' #{"style='display:none'" unless tariff.hts_1} data-action='auto-classify' country='#{c.country_id}' tariff-line-num='#{tariffLineNum}'>Auto-Classify</a><input type='hidden' value='#{c.country_id}' name='product[classifications_attributes][#{c.country_id}][class_cntry_id]' />"
    if tariffLineNum == 1
      schedB = $("#sched-b-tab-#{c.country_id} input").val()
      html += """<p class='sched-b-display' style='display: #{if schedB then "inline" else "none" }; padding-left: 20px;'>SCHED B: <span class='sched-b-display-val'>#{schedB}</span></p>"""
    if tariffLineNum > 1 && allowDelete
      html += "&nbsp;&nbsp;&nbsp;<small><button class='btn btn-sm btn-danger btn-delete' type='button' title='Delete'><i class='fa fa-trash'></i></button></small>"
    if c.id?
      html += "<input type='hidden' value='#{c.id}' name='product[classifications_attributes][#{c.country_id}][id]' />"
    if tariff.id
      html += "<input type='hidden' value='#{tariff.id}' name='product[classifications_attributes][#{c.country_id}][tariff_records_attributes][#{tariffLineNum}][id]' />"
    html   += "<input type='hidden' value='#{tariffLineNum}' name='product[classifications_attributes][#{c.country_id}][tariff_records_attributes][#{tariffLineNum}][line_number]'>"
    html += "</div>"
    html += "<div data-target='auto-classify' country='#{c.country_id}' tariff-line-num='#{tariffLineNum}'></div></div>"

  #Appends one HTS/Sched B field
  appendQuickClassifyTariff: (classification, tariff, selector, allowDelete) ->
    c = classification
    t = tariff
    if c.country.iso_code == "US" and t.line_number == 1
      schedBTag = "<div style='margin-top: 20px;'>SCHED B: <input type='text' class='sched_b_field' country='#{c.country_id}' tariff-line-num='#{t.line_number}' value='#{t.schedule_b_1 || ''}' name='product[classifications_attributes][#{c.country_id}][tariff_records_attributes][#{t.line_number}][hts_hts_1_schedb]' /><div class='tariff_result'></div></div>"
      $(selector).parent().find("div.sched-b-tab").append schedBTag
    $(selector).append(Chain.quickClassifyTariff c, t, allowDelete)
    Chain.addTariffCallbacks(c, t)


  #Inserts one HTS/Sched B field
  insertQuickClassifyTariff: (classification, tariff, selector) ->
    existingTariffLineNums = $(selector + " input.hts_field").map(() -> $(this).attr('tariff-line-num')).toArray()
    allLineNums = existingTariffLineNums.concat([tariff.line_number]).sort()
    previousLineNum = allLineNums.indexOf tariff.line_number
    previousTariffSel = "div[quick-class-content-id='#{classification.country_id}'] div.tariff[tariff-line-num='#{previousLineNum}']"
    $(Chain.quickClassifyTariff(classification, tariff, true)).insertAfter $(previousTariffSel)
    newTariffSel = "div[quick-class-content-id='#{classification.country_id}'] div.tariff[tariff-line-num='#{previousLineNum + 1}']"
    Chain.addTariffCallbacks(classification, tariff)

  addTariffCallbacks: (classification, tariff) ->
    c = classification
    t = tariff
    iconSel = $("div.quick_class_country[country_id='#{c.country_id}'] i")
    htsFields = $("div [quick-class-content-id='#{c.country_id}']").find(".sched_b_field, .hts_field")
    autoClassifyButtonSel = $("a[data-action='auto-classify'][country='#{c.country_id}'][tariff-line-num='#{t.line_number}']")

    Chain.addTariffValidationCallback('invalid',c.country_id, t.line_number, do (c, t) ->
      (bad_hts) ->
        iconSel.removeClass('fa fa-check-circle fa-question-circle fa-exclamation-triangle').addClass('fa fa-times-circle')
        autoClassifyButtonSel.hide()
    )
    Chain.addTariffValidationCallback('empty',c.country_id, t.line_number, do (c, t) ->
      () ->
        errorThisCountry = emptyHtsThisCountry = false
        htsFields.each () ->
          errorThisField = $(@).hasClass('error')
          errorThisCountry = true if errorThisField
          emptyHtsThisField = $(@).val().length == 0 && $(@).hasClass('hts_field')
          emptyHtsThisCountry = true if emptyHtsThisField
          if !errorThisField && emptyHtsThisField
            autoClassifyButtonSel.hide()

        if !errorThisCountry && emptyHtsThisCountry
          autoClassCount = $(".tariff[tariff-line-num='#{t.line_number}'][country='#{c.country_id}']").find(".auto-class-container").length
          if autoClassCount > 1
            # If there are multiple auto-classify options, restore the question-mark icon
            iconSel.removeClass('fa fa-times-circle fa-exclamation-triangle fa-check-circle').addClass('fa fa-question-circle')
          else
            iconSel.removeClass('fa fa-times-circle fa-question-circle fa-exclamation-triangle fa-check-circle')

        # Errored Sched B has been cleared
        else if !emptyHtsThisCountry
          iconSel.removeClass('fa fa-times-circle fa-question-circle fa-exclamation-triangle').addClass('fa fa-check-circle')
    )
    Chain.addTariffValidationCallback('valid',c.country_id, t.line_number, do (c, t) ->
      (good_hts) ->
        errorThisCountry = emptyHtsThisCountry = false
        htsFields.each () ->
          errorThisField = $(@).hasClass('error')
          errorThisCountry = true if errorThisField
          emptyHtsThisField = $(@).val().length == 0 && $(@).hasClass('hts_field')
          emptyHtsThisCountry = true if emptyHtsThisField
          unless errorThisField || emptyHtsThisField
            autoClassifyButtonSel.show()

        countrySel = $("div.quick_class_country[country_id='#{c.country_id}']")
        # If the exclamation point has been set that also implies that HTS is valid, so don't replace it
        unless errorThisCountry || emptyHtsThisCountry || countrySel.find('.fa-exclamation-triangle').length > 0
          countrySel.find('i').removeClass('fa fa-times-circle fa-question-circle fa-exclamation-triangle').addClass('fa fa-check-circle')
    )
    $("div[quick-class-content-id='#{c.country_id}'] .btn-delete").click (evt) ->
      evt.preventDefault()
      countryId = $(@).closest("div.quick_class_target").attr('quick-class-content-id')
      $(@).closest("div.tariff").remove()
      Chain.updateTariffList countryId

    # Synchronize Sched B fields on HTS/Sched B tabs
    $("input.sched_b_field[country='#{c.country_id}']").blur (evt) ->
      newValue = $(this).val()
      contentSel = $("div[quick-class-content-id='#{c.country_id}']")
      schedBSel = contentSel.find(".sched-b-display")
      if newValue.length > 0
        contentSel.find(".sched-b-display-val").html newValue
        schedBSel.css("display", "inline")
      else
        schedBSel.hide()

  nextTariffLineNum: (countryId) ->
    lineNums = $("input.hts_field[country='#{countryId}']").map(() -> parseInt $(this).attr('tariff-line-num')).toArray()
    if lineNums.length > 0
      #Applies max function to arrays. See https://stackoverflow.com/a/6102340/965613
      Math.max.apply(Math, lineNums) + 1
    else 1

  updateTariffList: (countryId) ->
    htsList = $("div[quick-class-content-id='#{countryId}'] input.hts_field").map(() -> $(this).val()).toArray().join("</br>")
    htsCell = $("table#quick_class_table div.quick_class_country[country_id='#{countryId}']").closest('tr').find('td.tariff-list')
    htsCell.html("<div>#{htsList}</div>")

  countryLookup: () ->
    lookup = {}
    $('.quick_class_country').each () ->
      id = $(@).attr("country_id")
      name = $(@).find('a').html()
      lookup[id] = name
    lookup

  # return names of countries that have a blank tariff followed by a populated one
  countriesWithBlankTariffs: () ->
    countryList = []
    lookup = Chain.countryLookup()
    $('.quick_class_target').each () ->
      countryId = parseInt $(@).attr('quick-class-content-id')
      tariffList = $(@).find('.tariff').map () ->
                     htsValue = $(@).find('.hts_field').val()
                     tariffLineNum = parseInt $(@).attr("tariff-line-num")
                     {lineNumber: tariffLineNum, hts: htsValue}
      sortedTariffList = tariffList.sort (a, b) ->
                           if a.lineNumber > b.lineNumber
                             1
                           else if a.lineNumber < b.lineNumber
                             -1
                           else
                             0
      $.each sortedTariffList, (idx, t) ->
        if (sortedTariffList[idx + 1] && sortedTariffList[idx + 1] != "") && t.hts == ""
          countryList.push lookup[countryId]
          return
    countryList

  #show modal for quick classify window based on given product json and saveUrl
  showQuickClassify : (product,saveUrl,bulk_options) ->
    Chain.quickClassifyProduct = product
    writeClassification = (c) ->
      hts_val = c.tariff_records[0]?.hts_1 ? ""
      sched_b_val = c.tariff_records[0]?.schedule_b_1 ? ""
      $("#quick_class_table").append """
        <tr>
          <td>
            <div class='quick_class_country' country_id='#{c.country_id}'>
              <div class='icon-container'>
                <i class='#{if hts_val.length then 'fa fa-check-circle' else ''}'></i>
              </div>
              <a href='#' country_id='#{c.country_id}' data-action='quick-class-country'>#{c.country.name}</a>
            </div>
          </td>
          <td class='tariff-list'></td>
        </tr>
        """
      $("#quick_class_content").append """
        <div quick-class-content-id='#{c.country_id}' class='quick_class_target hts_cell'>
          <div class= "tab-content">
            <div class='tab-pane fade show active hts-tab' id='hts-tab-#{c.country_id}' role='tabpanel' aria-labelledby='hts-tab'></div>
            <div class='tab-pane fade sched-b-tab' id='sched-b-tab-#{c.country_id}' role='tabpanel' aria-labelledby='sched-b-tab'></div>
          </div>
        </div>
        """
      # Every classification should start with at least one tariff
      c.tariff_records.push {} unless c.tariff_records.length > 0
      for t, idx in c.tariff_records
        t.line_number = idx + 1 unless t.line_number  #callbacks need a line number to latch onto
        Chain.appendQuickClassifyTariff c, t, "div[quick-class-content-id='#{c.country_id}'] div.hts-tab"

     #The containing quick_class_target div needs to contract when tabs are visible and expand when they're not
    changeTabs = (action) ->
      tabsSel = $('#quick_class_content ul.nav-tabs')
      qcSel = $('.quick_class_target')
      if action == "show" && tabsSel.css("display") == "none"
        tabsSel.show "fade",200, () ->
          qcSel.each () -> $(@).css("height", $(@).height() - tabsSel.height())
      else if action == "hide" && tabsSel.css("display") != "none"
        tabsHeight = tabsSel.height()
        tabsSel.hide () ->
          qcSel.each () -> $(@).css("height", $(@).height() + tabsHeight)

    modal = $("#mod_quick_classify")
    unless modal.length
      $('body').append("<div style='display:none;' id='mod_quick_classify' class='ui-front'>x</div>")
      modal = $("#mod_quick_classify")
    modal.html("")

    h = "<form>"
    if bulk_options
      if bulk_options["sr_id"]
        h += "<input type='hidden' value='"+bulk_options["sr_id"]+"' name='sr_id' />"
      if bulk_options["pk"]
        pk_counter = 0
        for p in bulk_options["pk"]
          h += "<input type='hidden' value='"+p+"' name='pk["+pk_counter+"]' />"
          pk_counter++
    h += "<div class='quick_class_outer'>"
    h += "<div id='quick_class_content'></div>"
    h += "<div id='quick_class_countries'><table id='quick_class_table'></table></div>"
    h += "</div></form>"
    modal.html(h)
    writeClassification(c) for c in product.classifications
    Classify.enableHtsChecks() #check for HTS values inline
    Chain.updateTariffList(c.country_id) for c in product.classifications
    $('#quick_class_content').prepend """
      <ul class='nav nav-tabs' style="display: none;" role='tablist'>
        <li class='nav-item'>
          <a class='nav-link active' id='hts-tab' data-toggle='tab' role='tab' aria-controls='hts' aria-selected='true'>HTS</a>
        </li>
        <li class='nav-item'>
          <a class='nav-link' id='sched-b-tab' data-toggle='tab' role='tab' aria-controls='hts' aria-selected='false'>Schedule B</a>
        </li>
      </ul>
      """
    RailsHelper.prepRailsForm modal.find("form"), saveUrl, (if bulk_options && (bulk_options["pk"] || bulk_options["sr_id"]) then 'post' else 'put')
    buttons = {
    'Save': (e) ->
      countriesWithBlankTariffs = Chain.countriesWithBlankTariffs()
      if countriesWithBlankTariffs.length > 0
        window.alert("A populated tariff line cannot appear after a blank one: #{countriesWithBlankTariffs.join(', ')} ")
      else if Classify.hasInvalidTariffs()
        window.alert("Please correct or erase all bad tariff numbers.")
      else
        # disable the save button, otherwise the user can repeatedly click it while the page loads, resulting in numerous identical http requests
        $(e.target).attr("disabled", true)
        $("#mod_quick_classify form").submit()
    'Cancel': () ->
      $("#mod_quick_classify").remove()
    'Additional Tariff': () ->
      countryId = parseInt $('#quick_class_table .selected .quick_class_country').attr("country_id")
      classi = Chain.quickClassifyProduct.classifications.find (cl) -> cl.country_id == countryId
      contentSel = "div[quick-class-content-id='#{countryId}']"
      nextLineNumber = Chain.nextTariffLineNum(countryId)
      Chain.appendQuickClassifyTariff(classi, {line_number: nextLineNumber}, (contentSel + ' div.hts-tab'), true)
      Chain.htsAutoComplete("div.tariff[country = '#{countryId}'][tariff-line-num= '#{nextLineNumber}'] input.hts_field")
      $(contentSel).scrollTop($(contentSel)[0].scrollHeight)

    }
    $("#quick_class_countries a").click((evt) ->
      evt.preventDefault()
      cid = $(@).attr('country_id')
      $("#quick_class_table tr.selected").removeClass("selected")
      $(@).closest("tr").addClass("selected")
      $("div[quick-class-content-id]").hide()
      $("div[quick-class-content-id='"+cid+"']").show("fade", 200)
      $('#hts-tab').attr("href", "#hts-tab-#{cid}")
      $('#sched-b-tab').attr("href", "#sched-b-tab-#{cid}")
      iso = (Chain.quickClassifyProduct.classifications.find (cl) -> parseInt(cid) == cl.country_id).country.iso_code
      if iso == "US" then changeTabs("show") else changeTabs("hide")
    )

    if bulk_options && (bulk_options["pk"] || bulk_options["sr_id"])
      buttons['Advanced'] = () ->
        # $("#mod_quick_classify") = modal (model not reference directly due to circular reference / garbage collection concerns)
        form = $("#mod_quick_classify").find("form")
        form.attr("action","/products/bulk_edit")
        form.data('trigger', 'advanced_button')
        form.submit()
    else
      buttons['Advanced'] = ->
        window.location = '/products/'+product.id+'/edit'
    modal.find("form").submit ->

      # If every field is blank, don't submit since there's nothing for the server to do here (plus it crashes if you submit a bulk classification with no data),
      # just close the classify popup instead.
      fields = $("input.hts_field")
      field_count = fields.length
      blank_count = 0
      fields.each ->
        if $(@).val()==''
          $(@).parents('div[quick-class-content-id]').remove()
          blank_count++

      should_submit = (blank_count != field_count) || $(@).data('trigger') == 'advanced_button'
      if !should_submit
        $("#mod_quick_classify").remove()
      else
        # We're clearing the user's search selections here to prevent the case where they selected something
        # classified it and then had those items they selected drop off their search (but still stay in their selections).
        clear_scope = $("#search_clear").scope()
        if clear_scope
          clear_scope.$apply((scope) ->
            scope.selectNone()
          )
      should_submit

    Chain.setupRegionModal()
    Chain.htsAutoComplete("input.hts_field")
    modal.dialog(title:"Quick Classify",width:960,buttons:buttons,resizable:false,modal:true)
    modal.dialog('open')

  setupRegionModal: () ->
    unless $("#region_modal").length
      $('body').append("<div style='display:none;' id='region_modal' class='ui-front'>x</div>")
    regionModal = $("#region_modal")
    if !regionModal.data("remotely-rendered")
      regionModal.dialog(title:"Select Countries",width:890,resizable:false,modal:true)
      countryIds = $(".quick_class_country a").map(() -> $(this).attr("country_id")).toArray()
      ChainAllPages.renderRemote(requestPath: "/products/show_region_modal?country_ids=#{countryIds}", target: "#region_modal")
    # not sure why this opens automatically
    regionModal.dialog('close')

  tariffPopUp : (htsNumber, country_id, country_iso) ->
    mod = $("#mod_tariff_popup")
    if(mod.length==0)
      $("body").append("<div id='mod_tariff_popup'><div id='tariff_popup_content'></div></div>")
      mod = $("#mod_tariff_popup")
      mod.dialog(
        autoOpen:false
        title:'Tariff Information'
        width:'400'
        height:'500'
        buttons:
          "Close": () ->
            $("#mod_tariff_popup").dialog('close')

      )

    c = $("#tariff_popup_content")
    c.html("Loading tariff information...")
    mod.dialog('open')
    url = '/official_tariffs/find?hts='+htsNumber
    if (country_id)
      url += "&cid="+country_id
    else if (country_iso)
      url += "&ciso="+country_iso

    htsDataRow = (label, data) ->
      html = ""
      if data!=undefined && $.trim(data).length > 0
        html = "<tr class='hover'><td class='lbl_hts_popup'>"+label+"</td><td>"+data+"</td></tr>"
      html

    $.ajax(
      url: url
      dataType: 'json'
      error: () ->
        c.html "We're sorry, an error occurred while trying to load this information."

      success: (data) ->
        h = "No data was found for tariff "+htsNumber
        if data && data.official_tariff
          h = ""
          o = data.official_tariff
          h = "<table class='tbl_hts_popup'><tbody>"
          h += htsDataRow("Country:",o.country.name)
          h += htsDataRow("Tariff #:",o.hts_code)
          h += "<span class='badge badge-warning' title='This product may require a Lacey Act declaration.'>Lacey Act</span>" if o.lacey_act == true
          h += htsDataRow("Common Rate:",o.common_rate)
          h += htsDataRow("General Rate:",o.general_rate)
          h += htsDataRow("Chapter:",o.chapter)
          h += htsDataRow("Heading:",o.heading)
          h += htsDataRow("Sub-Heading:",o.sub_heading)
          h += htsDataRow("Text:",o.remaining_description)
          h += htsDataRow("Special Rates:",o.special_rates)
          h += htsDataRow("Add Valorem:",o.add_valorem_rate)
          h += htsDataRow("Per Unit:",o.per_unit_rate)
          h += htsDataRow("UOM:",o.unit_of_measure)
          h += htsDataRow("MFN:",o.most_favored_nation_rate)
          h += htsDataRow("GPT:",o.general_preferential_tariff_rate)
          h += htsDataRow("Erga Omnes:",o.erga_omnes_rate)
          h += htsDataRow("Column 2:",o.column_2_rate)
          h += htsDataRow("Import Regulations:",o.import_regulations)
          h += htsDataRow("Export Regulations:",o.export_regulations)
          if o.binding_ruling_url
            h += htsDataRow("Binding Rulings:","<a href='"+o.binding_ruling_url+"' target='rulings'>Click Here</a>")
          if o.taric_url
            h += htsDataRow("TARIC:","<a href='"+o.taric_url+"' target='_blank'>Click Here</a>")
          if o.official_quota!=undefined
            h += htsDataRow("Quota Category",o.official_quota.category)
            h += htsDataRow("SME Factor",o.official_quota.square_meter_equivalent_factor)
            h += htsDataRow("SME UOM",o.official_quota.unit_of_measure)

          h += htsDataRow("Notes:",o.notes)
          if o.auto_classify_ignore
            h += htsDataRow("Ignore For Auto Classify","Yes")

          h += "</tbody></table>"

        c.html(h)
    )

$(document).ready () ->
  # This includes this header in literally every jQuery ajax call.
  # Note, this header is included twice, since jquery.form also 'helpfully' reads the crsf token and injects it as well
  $.ajaxSetup({headers: {"X-CRSF-Token": ChainAllPages.getAuthToken()}})

  $("#lnk_hide_notice").click (evt) ->
    evt.preventDefault
    $('#notice').hide()

  $('#notice').slideDown('slow')

  $(document).on 'click', "a.click_sink", (evt) ->
    evt.preventDefault()

  $(document).on 'click', "a[data-action='auto-classify']", (evt) ->
    evt.preventDefault()
    regionModal = $('#region_modal')
    regionModal.data("hts", $(@).parent().find('.hts_field').val())
    regionModal.data("tariff-line-num", parseInt($(@).attr('tariff-line-num')))
    regionModal.data("country", $(@).attr('country'))
    regionModal.dialog('open')

  $(document).on 'click', "a.lnk_tariff_popup", (evt) ->
    evt.preventDefault()
    hts = $(@).attr('hts')
    c_id = $(@).attr('country')
    c_iso = $(@).attr('iso')
    Chain.tariffPopUp hts, c_id, c_iso

  $(document).on 'click', "a.hts_option", (evt) ->
    evt.preventDefault()
    h = $(@).parents(".tariff").find("input.hts_field")
    h.val($(@).html())
    h.blur()

  $(document).on 'click', '.btn_link', (evt) ->
    # TODO Pull Key Mapping into this file
    evt.preventDefault()
    link = $(@).attr('link_to')
    if link
      if link == "back"
        window.history.back()
      else
        window.location=link

  $(document).on 'show.bs.tab', '[tab-src]', (evt) ->
    t = $(this)
    if t.attr('tab-src-reload')=='true' || !t.attr('tab-src-loaded')
      src = t.attr('tab-src')
      targetPane = $(t.attr('href'))
      if t.attr('tab-src-loading')!='y'
        t.attr('tab-src-loading','y')
        $.ajax {
          method:'get'
          url: src
          success: (data) ->
            targetPane.html(data)
          error: (data) ->
            targetPane.html("<div class='alert alert-danger'>There was an error loading this tab.  Please contact support.</div>")
        }

  $(document).on 'click', '[data-infinite-table-target]', (evt) ->
    targetTableSelector = $(evt.target).attr('data-infinite-table-target')
    Chain.processInfiniteSelectLoad(targetTableSelector)

  $(document).on 'click', '[data-infinite-table-reset]', (evt) ->
    targetTableSelector = $(evt.target).attr('data-infinite-table-reset')
    Chain.processInfiniteSelectReset(targetTableSelector)

  $(document).on 'keyup', '[data-infinite-table-filter]', (e) ->
    tgt = $(e.target)
    btn = $('button[data-infinite-table-reset="'+tgt.attr('data-infinite-table-filter')+'"]')
    if tgt.val().length > 0
      btn.removeClass('btn-secondary').addClass('btn-primary')
    else
      btn.addClass('btn-secondary').removeClass('btn-primary')
    if(e.keyCode == 13)
      targetTableSelector = $(e.target).attr('data-infinite-table-filter')
      Chain.processInfiniteSelectReset(targetTableSelector)

  $(document).on 'click', '.task-email-toggle', (evt) ->
    evt.preventDefault()
    $.ajax {
      method: "POST"
      url:'/users/task_email.json'
      success: (data) ->
        h = ''
        h = "<span class='fa fa-check-circle-o'></span>" if data.msg_state
        $('.task-wrap .task-email-check-wrap').html(h)
    }

  $(document).on 'blur', 'input.hts_field', () ->
        Chain.updateTariffList $(@).attr('country')

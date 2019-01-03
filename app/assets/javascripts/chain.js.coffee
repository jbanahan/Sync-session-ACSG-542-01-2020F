root = exports ? this
root.Chain =

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
    csrfToken = Chain.getAuthToken()
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
    $.post('/hide_message/'+messageName)

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

  htsAutoComplete : ->
    $("input.hts_field").each((inp) ->
      return if $(@).is(':data(autocomplete)')
      country = $(@).attr('country')
      $(@).autocomplete({
        source:(req,add) ->
          $.getJSON("/official_tariffs/auto_complete?country="+country+"&hts="+req.term, (data) ->
            r = []
            r.push(h) for h in data
            add(r)
          )
        select: (event,ui) ->
          $(@).val(ui.item.label)
          $(@).blur()
      })
    )

  #load auto classification values an populate into containers that match destination_selector and also have country='[country_id]'
  loadAutoClassifications : (hts,country_id,destination_selector) ->
    cleanHTS = hts.replace( /[^\dA-Za-z]/g, "" )
    jQuery.get '/official_tariffs/auto_classify/'+cleanHTS+'.json', (data) ->
      Chain.populateAutoClassifications destination_selector, data

  #fill the countries that match the destination_selectors with the classification date
  populateAutoClassifications : (destination_selector,data) ->
    write = (country_result) ->
      target = $(destination_selector+"[country='"+country_result.country_id+"']")
      h ="<div class='auto-class-title'>Auto Classifications</div>"
      for hts in country_result['hts']
        h += "<div class='auto-class-container'><a href='#' class='hts_option'>"+hts.code+"</a>"
        h += "&nbsp;<span class='badge badge-info' title='This tariff number is used about "+numberWithCommas(hts.use_count)+" times.' data-toggle='tooltip'>"+abbrNum(hts.use_count,2)+"</span>" if hts.use_count
        h += "&nbsp;<a href='#' class='lnk_tariff_popup btn btn-secondary btn-sm' iso='"+country_result.iso+"' hts='"+hts.code+"'>info</a>"
        h += "<br />"+hts.desc+"<br />"+"Common Rate: "+hts.rate+"<br />"
        h += "</div>"
      target.html(h)
    write cntry for cntry in data

  #add callback that will be fired if user enters a tariff number that results in the given state
  #state options are "valid", "invalid", "empty"
  addTariffCallback : (state,country_id,callback) ->
    @tariffCallbacks = {} unless @tariffCallbacks
    cb_set = @tariffCallbacks[state]
    if !cb_set
      cb_set = {}
      @tariffCallbacks[state] = cb_set
    country_cb = cb_set[country_id]
    if !country_cb
      country_cb = []
      cb_set[country_id] = country_cb
    country_cb.push callback

  #fire these callbacks when a tariff field is flagged as valid
  fireTariffCallbacks : (state,country_id,bad_tariff_number) ->
    return unless @tariffCallbacks
    @tariffCallbacks = {} unless @tariffCallbacks
    cb_set = @tariffCallbacks[state]
    return unless cb_set
    country_cb = cb_set[country_id]
    return unless country_cb
    cb(bad_tariff_number) for cb in country_cb
    return

  #show modal for quick classify window based on given product json and saveUrl
  showQuickClassify : (product,saveUrl,bulk_options) ->
    classificationIndex = 0
    writeClassification = (c) ->
      hts_val = c.tariff_records[0]?.hts_1 ? ""
      sched_b_val = c.tariff_records[0]?.schedule_b_1 ? ""
      Chain.addTariffCallback('invalid',c.country_id,(bad_hts) ->
        $("div.quick_class_country[country_id='"+c.country_id+"']").removeClass('good_class').addClass('bad_class')
        $("a[data-action='auto-classify'][country='"+c.country_id+"']").hide()
      )
      Chain.addTariffCallback('empty',c.country_id,() ->
        $("div.quick_class_country[country_id='"+c.country_id+"']").removeClass('bad_class').removeClass('good_class')
        $("a[data-action='auto-classify'][country='"+c.country_id+"']").hide()
      )
      Chain.addTariffCallback('valid',c.country_id,(good_hts) ->
        $("div.quick_class_country[country_id='"+c.country_id+"']").removeClass('bad_class').addClass('good_class')
        $("a[data-action='auto-classify'][country='"+c.country_id+"']").show()
      )
      $("#quick_class_countries").append("<div class='quick_class_country "+(if hts_val.length then "good_class" else "")+"' country_id='"+c.country_id+"'><a href='#' country_id='"+c.country_id+"' data-action='quick-class-country'>"+c.country.name+"</a></div>")
      r = "<div quick-class-content-id='"+c.country_id+"' class='quick_class_target hts_cell' >"
      r += "<div>"
      r += "<input type='hidden' value='"+c.country_id+"' name='product[classifications_attributes]["+classificationIndex+"][class_cntry_id]' />"
      r += "HTS: <input type='text' class='hts_field' country='"+c.country_id+"' value='"+hts_val+"' id='product_classification_attributes_"+classificationIndex+"_tariff_records_attributes_0_hts_hts_1' name='product[classifications_attributes]["+classificationIndex+"][tariff_records_attributes][0][hts_hts_1]' />"
      if c.id?
        r += "<input type='hidden' value='"+c.id+"' name='product[classifications_attributes]["+classificationIndex+"][id]' />"
      if c.tariff_records[0]?.id
        r += "<input type='hidden' value='"+c.tariff_records[0].id+"' name='product[classifications_attributes]["+classificationIndex+"][tariff_records_attributes][0][id]' />"
      r += "&nbsp;<a href='#' class='btn btn-sm btn-secondary' data-action='auto-classify' style='display:none;' country='"+c.country_id+"'>Auto-Classify</a>"
      r += "</div>"
      r += "<div data-target='auto-classify' country='"+c.country_id+"'></div>"
      if c.country.iso_code=='US'
        r += "<hr /><div>SCHED B: <input type='text' class='sched_b_field' country='"+c.country_id+"' value='"+sched_b_val+"' name='product[classifications_attributes]["+classificationIndex+"][tariff_records_attributes][0][hts_hts_1_schedb]' /><div class='tariff_result'></div></div>"
      r += "</div>"
      classificationIndex++
      $("#quick_class_content").append(r)
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
    h += "<div id='quick_class_content'></div><div id='quick_class_countries'></div>"
    h += "</div></form>"
    modal.html(h)
    writeClassification(c) for c in product.classifications
    Classify.enableHtsChecks() #check for HTS values inline

    RailsHelper.prepRailsForm modal.find("form"), saveUrl, (if bulk_options && (bulk_options["pk"] || bulk_options["sr_id"]) then 'post' else 'put')
    buttons = {
    'Cancel': () ->
      $("#mod_quick_classify").remove()
    'Save': (e) ->
      if Classify.hasInvalidTariffs()
        window.alert("Please correct or erase all bad tariff numbers.")
      else
        # disable the save button, otherwise the user can repeatedly click it while the page loads, resulting in numerous identical http requests
        $(e.target).attr("disabled", true)
        $("#mod_quick_classify form").submit()
    }
    $("#quick_class_countries a").click((evt) ->
      evt.preventDefault()
      cid = $(@).attr('country_id')
      $("div.quick_class_country").removeClass("selected")
      $(@).parent("div.quick_class_country").addClass("selected")
      $("div[quick-class-content-id]").hide()
      $("div[quick-class-content-id='"+cid+"']").show("blind",{direction:'left'},500)
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

    Chain.htsAutoComplete()
    modal.dialog(title:"Quick Classify",width:550,buttons:buttons,modal:true)
    modal.dialog('open')


  getAuthToken : () ->
    # First check for the csrf cookie (since that's what angular uses as well), then fall back to the meta tag.
    token = $.cookie("XSRF-TOKEN")
    unless token
      token = $('meta[name="csrf-token"]').attr('content')
    token

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
          h += "<span class='label label-warning' title='This product may require a Lacey Act declaration.'>Lacey Act</span>" if o.lacey_act == true
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
  $.ajaxSetup({headers: {"X-CRSF-Token": Chain.getAuthToken()}})

  $("#lnk_hide_notice").click (evt) ->
    evt.preventDefault
    $('#notice').hide()

  $('#notice').slideDown('slow')

  $(document).on 'click', "a.click_sink", (evt) ->
    evt.preventDefault()

  $(document).on 'click', "a[data-action='auto-classify']", (evt) ->
    evt.preventDefault()
    Chain.loadAutoClassifications($(@).parent().find('.hts_field').val(),$(@).attr['country'],"div[data-target='auto-classify']")

  $(document).on 'click', "a.lnk_tariff_popup", (evt) ->
    evt.preventDefault()
    hts = $(@).attr('hts')
    c_id = $(@).attr('country')
    c_iso = $(@).attr('iso')
    Chain.tariffPopUp hts, c_id, c_iso

  $(document).on 'click', "a.hts_option", (evt) ->
    evt.preventDefault()
    h = $(@).parents(".hts_cell").find("input.hts_field")
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

  $(document).on 'click', '.email-message-toggle', (evt) ->
    evt.preventDefault()
    $.ajax {
      url:'/users/email_new_message.json'
      success: (data) ->
        h = ''
        h = "<span class='fa fa-check-circle-o'></span>" if data.msg_state
        $('.message-wrap .email-message-check-wrap').html(h)
    }
  $(document).on 'click', '.task-email-toggle', (evt) ->
    evt.preventDefault()
    $.ajax {
      url:'/users/task_email.json'
      success: (data) ->
        h = ''
        h = "<span class='fa fa-check-circle-o'></span>" if data.msg_state
        $('.task-wrap .task-email-check-wrap').html(h)
    }

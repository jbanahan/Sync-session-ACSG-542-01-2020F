root = exports ? this
root.Chain =

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
  loadUserList : (selectBox,defaultSelection) ->
    url = '/users.json' unless url
    jQuery.get url, (data) ->
      Chain.populateUserList selectBox, defaultSelection, data

  #
  # Tariff Classification Mangaement Stuff
  #

  htsAutoComplete : ->
    $("input.hts_field").each((inp) ->
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
        h += "&nbsp;[<a href='#' class='lnk_tariff_popup' iso='"+country_result.iso+"' hts='"+hts.code+"'>info</a>]"
        h += "<br />"+hts.desc+"<br />"+"Common Rate: "+hts.rate+"<br /></div>"
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
      r += "<input type='hidden' value='"+c.country_id+"' name='product[classifications_attributes]["+classificationIndex+"][country_id]' />"
      r += "HTS: <input type='text' class='hts_field' country='"+c.country_id+"' value='"+hts_val+"' id='product_classification_attributes_"+classificationIndex+"_tariff_records_attributes_0_hts_1' name='product[classifications_attributes]["+classificationIndex+"][tariff_records_attributes][0][hts_1]' />"
      if c.id?
        r += "<input type='hidden' value='"+c.id+"' name='product[classifications_attributes]["+classificationIndex+"][id]' />"
      if c.tariff_records[0]?.id
        r += "<input type='hidden' value='"+c.tariff_records[0].id+"' name='product[classifications_attributes]["+classificationIndex+"][tariff_records_attributes][0][id]' />"
      r += "&nbsp;<a href='#' data-action='auto-classify' style='display:none;' country='"+c.country_id+"'>Auto-Classify</a>"
      r += "</div>"
      r += "<div data-target='auto-classify' country='"+c.country_id+"'></div>"
      r += "</div>"
      classificationIndex++
      $("#quick_class_content").append(r)
    modal = $("#mod_quick_classify")
    unless modal.length
      $('body').append("<div style='display:none;' id='mod_quick_classify'>x</div>")
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
    OpenChain.enableHtsChecks() #check for HTS values inline
    RailsHelper.prepRailsForm modal.find("form"), saveUrl, (if bulk_options && (bulk_options["pk"] || bulk_options["sr_id"]) then 'post' else 'put')
    buttons = {
    'Cancel': () ->
      $("#mod_quick_classify").remove()
    'Save': () ->
      if OpenChain.hasInvalidTariffs()
        window.alert("Please correct or erase all bad tariff numbers.")
      else
        $("#mod_quick_classify form").submit()
    }
    $("#quick_class_countries a").click((evt) ->
      evt.preventDefault()
      cid = $(@).attr('country_id')
      $("div.quick_class_country").removeClass("selected")
      $(@).parent("div.quick_class_country").addClass("selected")
      $("div[quick-class-content-id]").hide()
      $("div[quick-class-content-id='"+cid+"']").show("slide",{direction:"left"},500)
    )
    if bulk_options && (bulk_options["pk"] || bulk_options["sr_id"])
      buttons['Advanced'] = () ->
        modal.find("form").attr("action","/products/bulk_classify")
        modal.find("form").submit()
    else
      buttons['Advanced'] = ->
        window.location = '/products/'+product.id+'/classify'
    modal.find("form").submit ->
      $("input.hts_field").each ->
        $(@).parents('div[quick-class-content-id]').remove() if $(@).val()==''
    Chain.htsAutoComplete()
    modal.dialog(title:"Quick Classify",width:550,buttons:buttons,modal:true)
    modal.dialog('open')

$("a[data-action='auto-classify']").live 'click', (evt) ->
  evt.preventDefault()
  Chain.loadAutoClassifications($(@).parent().find('.hts_field').val(),$(@).attr['country'],"div[data-target='auto-classify']")


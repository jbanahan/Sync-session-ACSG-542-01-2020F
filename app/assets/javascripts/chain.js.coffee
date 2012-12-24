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

  #show modal for quick classify window based on given product json and saveUrl
  showQuickClassify : (product,saveUrl) ->
    classificationIndex = 0
    writeClassification = (c) ->
      r = "<tr><td>"+c.country.name+"</td><td>"
      r += "<input type='hidden' value='"+c.country_id+"' name='product[classifications_attributes]["+classificationIndex+"][country_id]' />"
      r += "<input type='text' value='"+(if c.tariff_records[0].hts_1 then c.tariff_records[0].hts_1 else "")+"' name='product[classifications_attributes]["+classificationIndex+"][tariff_records_attributes][0][hts_1]' />"
      r += "</td></tr>"
      classificationIndex++
      r
    modal = $("#mod_quick_classify")
    unless modal.length
      $('body').append("<div style='display:none;' id='mod_quick_classify'>x</div>")
      modal = $("#mod_quick_classify")
    modal.html("")
    h = "<form><table>"
    h += writeClassification(c) for c in product.classifications
    h += "</table></form>"
    modal.html(h)
    RailsHelper.prepRailsForm modal.find("form"), saveUrl, 'post'
    modal.dialog(title:"Quick Classify",width:400,buttons:{
    'Cancel': () ->
      $("#mod_quick_classify").remove()
    'Save': () ->
      $("#mod_quick_classify form").submit()
    })
    modal.dialog('open')

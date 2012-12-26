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
  showQuickClassify : (product,saveUrl,bulk_options) ->
    classificationIndex = 0
    writeClassification = (c) ->
      r = "<tr><td>"+c.country.name+"</td><td>"
      r += "<input type='hidden' value='"+c.country_id+"' name='product[classifications_attributes]["+classificationIndex+"][country_id]' />"
      r += "<input type='text' class='hts_field' country='"+c.country_id+"' value='"+(if c.tariff_records[0].hts_1 then c.tariff_records[0].hts_1 else "")+"' name='product[classifications_attributes]["+classificationIndex+"][tariff_records_attributes][0][hts_1]' />"
      r += "</td></tr>"
      classificationIndex++
      r
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
    h += "<table class='detail_table'><thead><tr><th>Country</th><th>HTS 1</th></tr></thead><tbody>"
    h += writeClassification(c) for c in product.classifications
    h += "</tbody></table></form>"
    modal.html(h)
    OpenChain.enableHtsChecks() #check for HTS values inline
    RailsHelper.prepRailsForm modal.find("form"), saveUrl, 'post'
    buttons = {
    'Cancel': () ->
      $("#mod_quick_classify").remove()
    'Save': () ->
      $("#mod_quick_classify form").submit()
    }
    if bulk_options && (bulk_options["pk"] || bulk_options["sr_id"])
      buttons['Advanced'] = () ->
        modal.find("form").attr("action","/products/bulk_classify")
        modal.find("form").submit()
    modal.dialog(title:"Quick Classify",width:400,buttons:buttons)
    modal.dialog('open')

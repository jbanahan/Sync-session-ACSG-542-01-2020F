root = exports ? this
root.BulkActions =
  
  #create and submit a bulk action form
  #if an ajaxCallback is passed then the form will be submitted as a remote action
  #and the callback will be bound to ajax:success
  submitBulkAction : (keys,searchId,path,method,ajaxCallback) ->
    $("#submit_bulk_action").remove()
    $("body").append("<form id='submit_bulk_action' class='bulk_form'></form>")
    sba = $("#submit_bulk_action")
    if searchId && !isNaN(searchId)
      sba.append("<input type='hidden' name='sr_id' value='"+searchId+"'/>") 
    else if keys
      sba.append("<input type='hidden' name='pk["+i+"]' value='"+k+"'/>") for k, i in keys
      
    if ajaxCallback
      sba.attr 'data-remote', 'true'
      sba.bind 'ajax:success', ajaxCallback

    RailsHelper.prepRailsForm sba, path, method
    sba.submit()
    

  submitBulkClassify : () ->
    $("#frm_bulk").attr('data-remote','true')
    $("#frm_bulk").attr('action','/products/bulk_classify.json')
    $("#frm_bulk").bind("ajax:success",BulkActions.handleBulkClassify)
    $("#frm_bulk").submit()

  handleBulkClassify : (xhr,data,status) ->
    bulk_options = {}
    pass_bulk = false
    sr = $("form.bulk_form").find("input[name='sr_id']")
    if sr.length
      bulk_options["sr_id"] = sr.val()
      pass_bulk = true
    pks = $("form.bulk_form").find("input[name^='pk[']")
    if pks.length
      bulk_options["pk"] = []
      bulk_options["pk"].push($(p).val()) for p in pks
      pass_bulk = true
    if pass_bulk
      Chain.showQuickClassify data.product, '/products/bulk_update_classifications', bulk_options
    else
      Chain.showQuickClassify data.product, '/products/bulk_update_classifications'

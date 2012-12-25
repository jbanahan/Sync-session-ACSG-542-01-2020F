root = exports ? this
root.BulkActions =
  submitBulkClassify : () ->
    $("#frm_bulk").attr('data-remote','true')
    $("#frm_bulk").attr('action','/products/bulk_classify.json')
    $("#frm_bulk").bind("ajax:success",BulkActions.handleBulkClassify)
    $("#frm_bulk").submit()

  handleBulkClassify : (xhr,data,status) ->
    bulk_options = {}
    pass_bulk = false
    sr = $("#frm_bulk").find("input[name='sr_id']")
    if sr.length
      bulk_options["sr_id"] = sr.val()
      pass_bulk = true
    pks = $("#frm_bulk").find("input[name^='pk[']")
    if pks.length
      bulk_options["pk"] = []
      bulk_options["pk"].push($(p).val()) for p in pks
      pass_bulk = true
    if pass_bulk
      Chain.showQuickClassify data.product, '/products/bulk_update_classifications', bulk_options
    else
      Chain.showQuickClassify data.product, '/products/bulk_update_classifications'

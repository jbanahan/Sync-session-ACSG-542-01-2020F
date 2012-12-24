root = exports ? this
root.BulkActions =
  submitBulkClassify : () ->
    $("#frm_bulk").attr('data-remote','true')
    $("#frm_bulk").attr('action','/products/bulk_classify.json')
    $("#frm_bulk").bind("ajax:success",BulkActions.handleBulkClassify)
    $("#frm_bulk").submit()

  handleBulkClassify : (xhr,data,status) ->
    Chain.showQuickClassify data.product, '/products/bulk_update_classifications'

root = exports ? this

makeBulkActions = ->
  coreModule = ''
  return {
    setCoreModule : (cm) ->
      coreModule = cm
    #create and submit a bulk action form
    #if an ajaxCallback is passed then the form will be submitted as a remote action
    #and the callback will be bound to ajax:success
    submitBulkAction : (keys,searchId,path,method,ajaxCallback) ->
      $("#submit_bulk_action").remove()
      $("body").append("<form id='submit_bulk_action' class='bulk_form' style='display:none;'></form>")
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

    submitBulkComment: ->
      $("#frm_bulk").attr('data-remote','true')
      $("#frm_bulk").attr('action','/products/bulk_comment.json')
      $("#frm_bulk").bind("ajax:success",BulkActions.handleBulkComment)
      $("#frm_bulk").submit()

    handleBulkComment: (xhr,data,status) ->
      createBulkCommentModal = ->
        $('body').append('<div class="modal fade" id="bulk-comment-modal" tabindex="-1" role="dialog" aria-labelledby="" aria-hidden="true"><div class="modal-dialog"><div class="modal-content"><div class="modal-header"><button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button><h4 class="modal-title">Comment</h4></div><div class="modal-body"><label>Subject</label><input type="text" class="form-control" name="subject" /><label>Body</label><textarea class="form-control" name="body" rows="5"></textarea></div><div class="modal-footer"><button type="button" class="btn btn-default" data-dismiss="modal">Close</button><button type="button" class="btn btn-primary" id="bulk-comment-modal-submit">Comment</button></div></div></div></div>')
        $('#bulk-comment-modal-submit').click(BulkActions.completeBulkComment)
        $('#bulk-comment-modal')

      mod = $('#bulk-comment-modal')
      mod = createBulkCommentModal() unless mod.length > 0
      mod.find('.modal-title').html("Comment On <span class='text-danger'>"+data.count+"</span> Records")
      mod.modal('show')

    completeBulkComment: ->
      mod = $('#bulk-comment-modal')
      subj = mod.find('input[name="subject"]').val()
      body = mod.find('textarea[name="body"]').val()
      if !subj || !body || subj.length==0 || body.length == 0
        window.alert('You must enter a subject and body.')
        return

      sba = $('#submit_bulk_action')
      sba.children(':not(input[type="hidden"])').remove()
      sba.append('<input type="text" name="subject" value="'+subj+'" />')
      sba.append('<textarea name="body">'+body+'</textarea>')
      sba.append('<input type="text" name="module_type" value="'+coreModule+'" />')
      RailsHelper.prepRailsForm sba, '/comments/bulk', 'POST'
      sba.unbind("ajax:success",BulkActions.handleBulkComment)
      sba.submit()
      mod.modal('hide')
      window.alert('Your comments have been submitted in the background. They may take a few minutes to post.')

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

  }

root.BulkActions = makeBulkActions()

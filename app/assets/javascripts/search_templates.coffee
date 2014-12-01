root = exports ? this
root.OCSearchTemplates = 
  initPage: () ->
    $('#templates').on 'change', 'input[type="checkbox"][data-template-id]', () ->
      btn = $('#btn_add_to_user')
      if $('input[type="checkbox"][data-template-id]:checked').length > 0
        btn.show()
      else
        btn.hide()
    $('#btnAddUser').prop('disabled',true)
    Chain.loadUserList $('#userListSelect'), undefined, (box) ->
      $('#btnAddUser').prop('disabled',false).on 'click', ->
        jqueryObjs = $.map $('input[data-template-id'), (x) ->
          $(x)
        idsToAdd = OCSearchTemplates.extractSelectedTemplateIds(jqueryObjs)
        $('#modUsers').modal('hide')
        $('#modUsersAssigning').modal('show')
        $.ajax '/api/v1/admin/users/'+$('#userListSelect').val()+'/add_templates.json', {
          method:'POST',
          headers: { 
              Accept : "application/json",
              "Content-Type": "application/json"
          },
          data: JSON.stringify({'template_ids':idsToAdd}),
          success: ((response) ->
            $('#resultMessage').html('Templates added.')
            $('#resultMessagePanel').prop('class','panel panel-success').show()
            $('#modUsersAssigning').modal('hide')
          ),
          error: ((response) ->
            $('#resultMessage').html('Template add failed. Please contact support.')
            $('#resultMessagePanel').prop('class','panel panel-danger').show()
            $('#modUsersAssigning').modal('hide')
          )
        }
        
  extractSelectedTemplateIds: (checkboxes) ->
    r = []
    for b in checkboxes
      r.push b.attr('data-template-id') if b.is(':checked')
    r
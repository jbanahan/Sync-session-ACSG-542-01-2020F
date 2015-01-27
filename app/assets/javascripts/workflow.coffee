root = exports ? this
root.ChainWorkflow =
  reload: ->
    coreObj = ChainWorkflow.coreObject()
    ChainWorkflow.reloadWorkflow(coreObj.coreModule,coreObj.baseObjectId)
    ChainWorkflow.loadOpenCount(coreObj.coreModule,coreObj.baseObjectId)

  initWorkflowButtons: () ->
    return false if root.workflowButtonsInitRun
    $(document).on 'click', '[data-wtask-multi-opt]', (evt) ->
      # evt.preventDefault()
      btn = $(this)
      wfId = btn.attr('data-wtask-id')
      $.ajax {
        url:'/api/v1/workflow/'+wfId+'/set_multi_state.json'
        contentType:'application/json'
        type:'PUT'
        dataType: 'json'
        data: JSON.stringify({state:btn.attr('data-wtask-multi-opt')})
        success: (data) ->
          success(data)
      }
    $(document).on 'click', 'a[data-assign-workflow-user]', (evt) ->
      # evt.preventDefault()
      lnk = $(this)
      wfId = lnk.attr('data-wtask-id')
      payload = {user_id:lnk.attr('data-assign-workflow-user')}
      if lnk.attr('data-assigned')=='true'
        payload = {}
      $.ajax {
        url:'/api/v1/workflow/'+wfId+'/assign.json'
        contentType:'application/json'
        type:'PUT'
        dataType: 'json'
        data: JSON.stringify(payload)
        success: (data) ->
          success(data)
      }

    root.workflowButtonsInitRun = true
    return true

  reloadWorkflow: (coreModule,baseObjectId) ->
    mb = $('#modal-workflow .workflow-content')
    mb.html('loading')
    $.ajax {
      url: '/workflow/'+coreModule+'/'+baseObjectId
      type:'GET'
      success: (data) ->
        mb.html(data)
        mb.trigger('chain:workflow-load')
      error: (data,status,errorThrown) ->
        mb.html("<div class='alert alert-danger'>There was an error loading this workflow data.  Please contact support.</div>")
    }

  loadOpenCount: (coreModule,baseObjectId) ->
    $.ajax {
      url:'/api/v1/workflow/'+coreModule+'/'+baseObjectId+'/my_instance_open_task_count'
      contentType:'application/json'
      type:'GET'
      dataType: 'json'
      success: (data) ->
        $('.workflow-nav-icon').addClass('workflow-nav-icon-has-tasks') if data.count > 0
    }

  coreObject: () ->
    modal = $('#modal-workflow')
    rVal = {}
    rVal.coreModule = modal.attr('data-wf-core-module')
    rVal.baseObjectId = modal.attr('data-wf-obj-id')
    rVal

  initWorkflow: ->
    coreObj = ChainWorkflow.coreObject()
    ChainWorkflow.loadOpenCount(coreObj.coreModule,coreObj.baseObjectId)
    ChainWorkflow.initWorkflowButtons (data) ->
      ChainWorkflow.reload()
    $(document).on 'show.bs.modal', '#modal-workflow', () ->
      ChainWorkflow.reload()

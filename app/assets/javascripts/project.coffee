projectApp = angular.module('ProjectApp',['ChainComponents'])
projectApp.factory 'projectSvc', ['$http',($http) ->
  return {
    project: null
    loadingMessage: null
    errorMessage: null
    load: (projectId) ->
      svc = @
      svc.loadingMessage = 'Loading...'
      $http.get('/projects/'+projectId+'.json').then(((resp) ->
        svc.project = resp.data.project
        svc.loadingMessage = null
      ),((resp) ->
        svc.errorMessage = resp.data.error
        svc.loadingMessage = null
      ))

    saveProject: (project) ->
      svc = @
      project.saving = true
      $http.put('/projects/'+project.id+'.json',{project:project}).then(((resp) ->
        svc.project = resp.data.project
      ),((resp) ->
        project.saving = null
        svc.errorMessage = resp.data.error
      ))

    addProjectUpdate: (project,body) ->
      svc = @
      project.saving = true
      $http.post('/projects/'+project.id+'/project_updates.json',{project_update:{body:body}}).then(((resp) ->
        project.project_updates ?= []
        project.project_updates.unshift resp.data.project_update
        project.saving = null
      ),((resp)->
        project.saving = null
        svc.errorMessage = resp.data.error
      ))

    editProjectUpdate: (project,projectUpdate) ->
      svc = @
      projectUpdate.saving = true
      $http.put('/projects/'+project.id+'/project_updates/'+projectUpdate.id+'.json',{project_update:projectUpdate}).then(((resp) ->
        update = resp.data.project_update
        project.project_updates ?= []
        for pu, i in project.project_updates
          project.project_updates[i] = update if pu.id == update.id
      ),((resp) ->
        projectUpdate.saving = null
        svc.errorMessage = resp.data.error
      ))

    saveDeliverable: (project,deliverable) ->
      svc = @
      deliverable.saving = true
      goodCallback = (resp) ->
        del = resp.data.project_deliverable
        project.project_deliverables ?= []
        for pd, i in project.project_deliverables
          project.project_deliverables[i] = del if pd.id == deliverable.id
      badCallback = (resp) ->
        deliverable.saving = null
        svc.errorMessage = resp.data.error
      if deliverable.id == undefined
        deliverable.id = new Date().getTime()
        $http.post('/projects/'+project.id+'/project_deliverables.json',{project_deliverable:deliverable}).then(goodCallback,badCallback)
      else
        $http.put('/projects/'+project.id+'/project_deliverables/'+deliverable.id+'.json',{project_deliverable:deliverable}).then(goodCallback,badCallback)

    toggleClose: (project) ->
      svc = @
      project.saving = true
      $http.put('/projects/'+project.id+'/toggle_close.json').then(((resp) ->
        svc.project = resp.data.project
      ),((resp) ->
        project.saving = null
        svc.errorMessage = resp.data.error
      ))
  }
]
projectApp.filter 'deliverableSort', [() ->
  (deliverables) ->
    r = if deliverables then deliverables.slice(0) else []
    r.sort (a,b) ->
      x = 0
      
      # sort by complete status
      a_comp = (if a.complete then 1 else 0)
      b_comp = (if b.complete then 1 else 0)
      x = a_comp - b_comp
      return x unless x==0

      # sort by due duate
      a_due = (if a.due_date then new Date(a.due_date) else new Date(2999,1,1))
      b_due = (if b.due_date then new Date(b.due_date) else new Date(2999,1,1))
      x = a_due.getTime() - b_due.getTime()
      return x unless x==0

      # sort by id
      a.id ?= 999999
      b.id ?= 999998
      x = a.id - b.id
      return x

]
projectApp.controller 'ProjectCtrl', ['$scope','projectSvc','userListCache',($scope,projectSvc,userListCache) ->
  $scope.addUpdateBody = ''
  $scope.svc = projectSvc
  $scope.users = []
  userListCache.getListForCurrentUser (userList) ->
    $scope.users = userList

  $scope.saveProject = () ->
    projectSvc.saveProject projectSvc.project
  $scope.toggleClose = () ->
    projectSvc.toggleClose projectSvc.project
  $scope.addProjectUpdate = () ->
    projectSvc.addProjectUpdate projectSvc.project, $scope.addUpdateBody
    $scope.addUpdateBody = ''
  $scope.editProjectUpdate = (u) ->
    projectSvc.editProjectUpdate projectSvc.project, u
  $scope.addDeliverable = () ->
    projectSvc.project.project_deliverables.push {edit:true}
  $scope.saveDeliverable = (d) ->
    projectSvc.saveDeliverable projectSvc.project, d

  $scope.svc.load $scope.projectId if $scope.projectId
]

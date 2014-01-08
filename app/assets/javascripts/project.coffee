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
projectApp.controller 'ProjectCtrl', ['$scope','projectSvc',($scope,projectSvc) ->
  $scope.addUpdateBody = ''
  $scope.svc = projectSvc

  $scope.saveProject = () ->
    projectSvc.saveProject projectSvc.project
  $scope.toggleClose = () ->
    projectSvc.toggleClose projectSvc.project
  $scope.addProjectUpdate = () ->
    projectSvc.addProjectUpdate projectSvc.project, $scope.addUpdateBody
    $scope.addUpdateBody = ''

  $scope.svc.load $scope.projectId if $scope.projectId
]

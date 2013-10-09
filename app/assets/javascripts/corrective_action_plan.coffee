capApp = angular.module('CorrectiveActionPlanApp',[])

capApp.factory 'correctiveActionPlanService', ['$http',($http) ->
  {
    #update the settings based on the data returned from the server
    settings: {
      canEdit:false
      canUpdateActions:false
      viewMode:'loading'
    }
    #base corrective aciton plan object
    cap: {}

    #comment to be added
    comment: ''

    #load settings from a server response
    setSettings:(data) ->
      @.settings.canEdit = data.can_edit
      @.settings.canUpdateActions = data.can_update_actions
    
    #add new issue to the plan
    addIssue:() ->
      @.cap.corrective_issues.push {}

    #load the plan from a server response
    setCorrectiveActionPlan: (data) ->
      @.cap = data.corrective_action_plan
      @.setSettings data
      @.addIssue() if (!@.cap.corrective_issues || @.cap.corrective_issues.length == 0) && @settings.canEdit
  
    makeUrl: (responseId,capId) ->
      '/survey_responses/'+responseId+'/corrective_action_plans/'+capId+'.json'
    
    setDataFromPromise: (promise,extraCallback) ->
      svc = @
      promise.then ((resp) ->
        svc.setCorrectiveActionPlan resp.data
        svc.settings.viewMode = 'edit'
        extraCallback(svc) if extraCallback
      ), ((resp) ->
        svc.settings.viewMode = 'error'
      )

    removeIssue: (issue) ->
      toRem = $.inArray(issue,@.cap.corrective_issues)
      @.cap.corrective_issues.splice(toRem,1) if toRem >= 0

    load: (surveyResponseId,correctiveActionPlanId) ->
      @.setDataFromPromise $http.get(@.makeUrl(surveyResponseId,correctiveActionPlanId))

    save: (surveyResponseId,correctiveActionPlanId) ->
      @.settings.viewMode = 'saving'
      @.setDataFromPromise $http.put(@.makeUrl(surveyResponseId,correctiveActionPlanId),{comment:@.comment,corrective_action_plan:@.cap}), (svc) ->
        svc.comment = ''
  }
]

capApp.controller 'CorrectiveActionPlanController', ['$scope','$http','correctiveActionPlanService',($scope,$http,correctiveActionPlanService) ->
  $scope.capService = correctiveActionPlanService
  $scope.settings = correctiveActionPlanService.settings

  $scope.capService.load($scope.survey_response_id,$scope.corrective_action_plan_id) if $scope.autoload

  $scope.addIssue = () ->
    $scope.capService.addIssue()

  $scope.save = () ->
    $scope.capService.save($scope.survey_response_id,$scope.corrective_action_plan_id)

  $scope.remove = (issue) ->
    $scope.capService.removeIssue(issue)
      
  $scope.$watch 'capService.cap', ((newVal,oldVal) ->
    $scope.cap = newVal
  )
]

capApp = angular.module 'CorrectiveActionPlanApp', ['ChainComponents']

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

    #load settings from a server response
    setSettings:(data) ->
      @.settings.canEdit = data.can_edit
      @.settings.canUpdateActions = data.can_update_actions
    
    #add new issue to the plan
    addIssue:() ->
      cap = @.cap
      $http.post('/corrective_issues',{corrective_action_plan_id:cap.id}).then(((resp)->
        cap.corrective_issues.push resp.data.corrective_issue
      ),((resp) ->
        svc.settings.viewMode = 'error'
      ))

    #add comment to the plan
    addComment: (comment, cap, surveyResponseId,successCallback) ->
      return if $.trim(comment).length == 0 #don't send empty comments
      svc = @
      svc.settings.newCommentSaving = true
      $http.post('/survey_responses/'+surveyResponseId+'/corrective_action_plans/'+cap.id+'/add_comment',{comment:comment}).then(((resp) ->
        #good response
        svc.settings.newCommentSaving = false
        cap.comments = [] if cap.comments==undefined
        cap.comments.push resp.data.comment
        successCallback resp.data unless successCallback==undefined
      ),(resp) ->
        #bad response
        svc.settings.newCommentSaving = false
        svc.settings.viewMode = 'error'
      )

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

    saveIssue: (issue) ->
      issue.saving = true
      svc = @
      $http.put('/corrective_issues/'+issue.id,{corrective_issue:issue}).then(((resp) ->
        #good
        issue.saving = false
      ),(resp) ->
        #bad
        issue.saving = false
        svc.viewMode = 'error'
      )

    removeIssue: (issue) ->
      toRem = $.inArray(issue,@.cap.corrective_issues)
      cap = @.cap
      if toRem >= 0
        $http.delete('/corrective_issues/'+issue.id).then(((resp) ->
          cap.corrective_issues.splice(toRem,1)
        ), ((resp) ->
          svc.settings.viewMode = 'error'
        ))

    load: (surveyResponseId,correctiveActionPlanId) ->
      @.setDataFromPromise $http.get(@.makeUrl(surveyResponseId,correctiveActionPlanId))

  }
]

capApp.controller 'CorrectiveActionPlanController', ['$scope','$http','correctiveActionPlanService',($scope,$http,correctiveActionPlanService) ->
  $scope.capService = correctiveActionPlanService
  $scope.settings = correctiveActionPlanService.settings

  $scope.capService.load($scope.survey_response_id,$scope.corrective_action_plan_id) if $scope.autoload

  $scope.addIssue = () ->
    $scope.capService.addIssue()

  $scope.saveIssue = (issue) ->
    $scope.capService.saveIssue(issue)

  $scope.addComment = () ->
    $scope.capService.addComment($scope.comment,$scope.capService.cap,$scope.survey_response_id,(data) ->
      $scope.comment = '' #clear on success
    )

  $scope.remove = (issue) ->
    $scope.capService.removeIssue(issue)
      
  $scope.$watch 'capService.cap', ((newVal,oldVal) ->
    $scope.cap = newVal
  )
]

capApp = angular.module 'CorrectiveActionPlanApp', ['ChainComponents']

capApp.factory 'correctiveActionPlanService', ['$http','$sce',($http,$sce) ->
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
      $http.post('/corrective_issues.json',{corrective_action_plan_id:cap.id}).then(((resp)->
        cap.corrective_issues.push resp.data.corrective_issue
      ),((resp) ->
        svc.settings.viewMode = 'error'
      ))

    #add comment to the plan
    addComment: (comment, cap, surveyResponseId,successCallback) ->
      return if $.trim(comment).length == 0 #don't send empty comments
      svc = @
      svc.settings.newCommentSaving = true
      $http.post('/survey_responses/'+surveyResponseId+'/corrective_action_plans/'+cap.id+'/add_comment.json',{comment:comment}).then(((resp) ->
        #good response
        svc.settings.newCommentSaving = false
        cap.comments = [] if cap.comments==undefined
        resp.data.comment.html_body = $sce.trustAsHtml(resp.data.comment.html_body)
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
      
      #mark textile rendered fields as html safe
      if @.cap
        if @.cap.corrective_issues
          for ci in @.cap.corrective_issues
            ci.html_description = $sce.trustAsHtml ci.html_description
            ci.html_suggested_action = $sce.trustAsHtml ci.html_suggested_action
            ci.html_action_taken = $sce.trustAsHtml ci.html_action_taken
        if @.cap.comments
          co.html_body = $sce.trustAsHtml(co.html_body) for co in @.cap.comments

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
      $http.put('/corrective_issues/'+issue.id+'.json',{corrective_issue:issue}).then(((resp) ->
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
        $http.delete('/corrective_issues/'+issue.id+'.json').then(((resp) ->
          cap.corrective_issues.splice(toRem,1)
        ), ((resp) ->
          svc.settings.viewMode = 'error'
        ))

    updateResolutionStatus: (issue) ->
      $http.post('/corrective_issues/'+issue.id+'/update_resolution', {is_resolved: issue.resolved}).then(((resp) ->
        # do nothing
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

  $scope.updateResolutionStatus = (issue) ->
    $scope.capService.updateResolutionStatus(issue)
]

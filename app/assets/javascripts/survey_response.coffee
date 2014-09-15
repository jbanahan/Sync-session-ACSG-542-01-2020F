srApp = angular.module 'SurveyResponseApp', ['ChainComponents','angularMoment']

srApp.factory 'srService', ['$http','$sce',($http,$sce) ->
  saveResponse = (r,buildData,success) ->
    r.saving = true
    promise = $http.put('/survey_responses/'+r.id+'.json',buildData(r))
    promise.then(((response) ->
      r.saving = false
      success(response) if success
    ),((response) ->
      r.saving = false
      r.error_message = "There was an error saving your data. Please reload the page."
    ))

  touch = (o) ->
    o.updated_at = new Date().toISOString()
    o.hours_since_last_update = 0 if o.hours_since_last_update

  return {
    resp: {}
    settings: {
      viewMode:'loading'
      filterMode: 'All'
    }

    filterModes: []
    
    load: (responseId) ->
      svc = @
      @.settings.viewMode = 'loading'
      $http.get('/survey_responses/'+responseId+'.json').then(((resp) ->
        svc.resp = resp.data.survey_response
        svc.settings.viewMode = 'view'
        svc.filterModes = ['All','Not Answered','Not Rated']
        if svc.resp.survey && svc.resp.survey.rating_values
          svc.filterModes.push("Rating: "+m) for m in svc.resp.survey.rating_values
        if svc.resp.answers
          ans.question.html_content = $sce.trustAsHtml(ans.question.html_content) for ans in svc.resp.answers
      ))

    addAnswerComment: (answer,content,isPrivate,extraCallback) ->
      promise = $http.post('/answers/'+answer.id+'/answer_comments.json',{comment:{content:content,private:isPrivate}})
      promise.then(((resp) ->
        answer.answer_comments = [] if answer.answer_comments == undefined
        answer.answer_comments.push resp.data.answer_comment
        touch answer
        extraCallback(answer) if extraCallback
      ), ((resp) ->
        answer.error_message = "There was an error saving your comment. Please reload the page."
      ))

    saveAnswer: (a,successCallback) ->
      a.saving = true
      promise = $http.put('/answers/'+a.id+'.json', {
        answer: {
          id:a.id
          choice:a.choice
          rating:a.rating
        }
      })
      promise.then(((response) ->
        a.saving = false
        touch a
        successCallback response if successCallback
      ), ((response) ->
        a.saving = false
        a.error_message = "There was an error saving your data. Please reload the page."
      ))

    saveContactInfo: (r) ->
      saveResponse r,(sr) ->
        {survey_response: {
          id:sr.id
          address:sr.address
          email:sr.email
          phone:sr.phone
          fax:sr.fax
          name:sr.name
          }
        }

    saveRating: (r) ->
      saveResponse r, (sr) ->
        {survey_response:{id:sr.id,rating:sr.rating}}
    
    submit: (r) ->
      saveResponse r, ((sr) ->
        {do_submit:true}
      ), (resp) ->
        r.success_message = 'Your survey has been submitted successfully.'
        r.can_submit = false
        r.status = 'Needs Rating'

    invite: (r) ->
      r.success_message = 'Sending invite.'
      $http.get('/survey_responses/'+r.id+'/invite.json').then(((response) ->
        r.success_message = 'Invite sent successfully.'
      ))
  }
]

srApp.controller('srController',['$scope','$filter','srService',($scope,$filter,srService) ->
  $scope.showSubmit = () ->
    $scope.srService.resp.can_submit
  $scope.srService = srService
  $scope.resp = srService.resp
  $scope.saveAnswer = (answer) ->
    $scope.srService.saveAnswer answer
    
  $scope.addComment = (answer) ->
    $scope.srService.addAnswerComment answer, answer.new_comment, answer.new_comment_private, (a) ->
      a.new_comment = null
      a.new_comment_private = null

  # set response's submitted state to true on server
  $scope.submit = () ->
    if !$scope.contact_form.$valid
      $scope.resp.error_message = 'You must complete all contact fields before submitting.'
    else if $scope.filterAnswers('Not Answered').length > 0
      $scope.resp.error_message = "You must answer all required questions. Use the 'Not Answered' filter to identify any questions that still need answers."
    else
      $scope.srService.submit($scope.resp)

  $scope.warningMessage = (answer) ->
    show_warning = $scope.showWarning(answer)
    has_comments = $scope.answerHasUserComments(answer)
    show_require_attachment = answer.question.require_attachment && !$scope.answerHasAttachments(answer)
    show_require_comment = answer.question.require_comment && !has_comments

    warning = ""
    if show_warning || show_require_attachment || show_require_comment
      warning += "This is a required question."
      if show_warning
        warning += if $scope.requiresMultipleChoiceAnswer(answer) then " You must provide an answer." else " You must provide a comment."
      if show_require_comment && warning.indexOf("provide a comment") < 0
        warning += " You must provide a comment."
      if show_require_attachment
        warning += " You must provide an attachment."
      
    warning

  $scope.requiresMultipleChoiceAnswer = (answer) ->
    answer.question.warning && answer.question.choice_list && answer.question.choice_list.length > 0

  $scope.showWarning = (answer) ->
    if answer.question.warning
      if $scope.requiresMultipleChoiceAnswer(answer)
        return !(answer.choice) || answer.choice.trim().length == 0
      else
        return if $scope.answerHasUserComments(answer) then false else true
    false

  $scope.answerHasUserComments = (answer) ->
    if answer.answer_comments
      for ac in answer.answer_comments
        return true if ac.user.id == $scope.resp.user.id && ac.content.trim().length > 0
    false

  $scope.answerHasAttachments = (answer) ->
    answer.attachments && answer.attachments.length > 0

  $scope.srService.load($scope.response_id) if $scope.response_id
  
  $scope.filterAnswers = (modeParam) ->
    mode = if modeParam then modeParam else (if $scope.srService.settings.filterMode then $scope.srService.settings.filterMode else "All")
    r = []
    return r unless $scope.resp.answers
    for a in $scope.resp.answers
      switch mode
        when 'Not Rated'
          r.push a if !a.rating || a.rating.length == 0
        when 'Not Answered'
          r.push a if $scope.warningMessage(a).length > 0
        else
          if mode.indexOf('Rating: ')==0
            targetRating = mode.slice(8,mode.length)
            r.push a if a.rating && a.rating == targetRating
          else
            r.push a
    $scope.filteredAnswers = r
    r

  $scope.hasUnsavedComments = () ->
    $filter('unsavedComments')($scope.resp.answers).length != 0

  $scope.$watch 'srService.resp', (newVal,oldVal, scope) ->
    $scope.resp = newVal
    scope.filterAnswers()
  
  $scope.$watch 'srService.settings.filterMode', (newVal,oldVal, scope) ->
    scope.filterAnswers()
  @
])

srApp.filter 'unsavedComments', () ->
  (answers) ->
    r = []
    return r unless answers
    for a in answers
      r.push a if a.new_comment && $.trim(a.new_comment).length > 0
    r

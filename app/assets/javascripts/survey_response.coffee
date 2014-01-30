srApp = angular.module 'SurveyResponseApp', ['ChainComponents','angularMoment']

srApp.factory 'srService', ['$http',($http) ->
  saveResponse = (r,buildData,success) ->
    r.saving = true
    promise = $http.put('/survey_responses/'+r.id,buildData(r))
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
      ))

    addAnswerComment: (answer,content,isPrivate,extraCallback) ->
      promise = $http.post('/answers/'+answer.id+'/answer_comments',{comment:{content:content,private:isPrivate}})
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
      promise = $http.put('/answers/'+a.id, {
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
    else if $filter('answer')($scope.resp.answers,'Not Answered').length > 0
      $scope.resp.error_message = 'You must select an answer or add a comment for every question before submitting. Use the Not Answered filter to identify any questions that still need answers.'
    else
      $scope.srService.submit($scope.resp)


  $scope.showWarning = (answer) ->
    return false unless answer.question.warning
    return false if answer.choice && answer.choice.length > 0
    if answer.answer_comments
      for ac in answer.answer_comments
        return false if ac.user.id == $scope.resp.user.id

    true

  $scope.srService.load($scope.response_id) if $scope.response_id
  

  filterAnswers = () ->
    $scope.filteredAnswers = $filter('answer')($scope.resp.answers,srService.settings.filterMode)

  $scope.filterAnswers = filterAnswers

  $scope.hasUnsavedComments = () ->
    $filter('unsavedComments')($scope.resp.answers).length != 0

  $scope.$watch 'srService.resp', (newVal,oldVal) ->
    $scope.resp = newVal
    filterAnswers()
  
  $scope.$watch 'srService.settings.filterMode', (newVal,oldVal) ->
    filterAnswers()
  @
])

srApp.filter 'answer', () ->
  (answers, mode) ->
    r = []
    return r unless answers
    for a in answers
      switch mode
        when 'Not Rated'
          r.push a if !a.rating || a.rating.length == 0
        when 'Not Answered'
          r.push a if (!a.choice || a.choice.length == 0) && (a.answer_comments==undefined || a.answer_comments.length==0)
        else
          if mode.indexOf('Rating: ')==0
            targetRating = mode.slice(8,mode.length)
            r.push a if a.rating && a.rating == targetRating
          else
            r.push a
     r

srApp.filter 'unsavedComments', () ->
  (answers) ->
    r = []
    return r unless answers
    for a in answers
      r.push a if a.new_comment && $.trim(a.new_comment).length > 0
    r

srApp = angular.module 'SurveyResponseApp', ['ChainComponents']

srApp.factory 'srService', ['$http',($http) ->
  saveResponse = (r,buildData) ->
    r.saving = true
    promise = $http.put('/survey_responses/'+r.id,buildData(r))
    promise.then(((response) ->
      r.saving = false
    ),((response) ->
      r.saving = false
      r.error_message = "There was an error saving your data. Please reload the page."
    ))

  return {
    resp: {}
    settings: {
      viewMode:'loading'
      filterMode: 'All'
    }

    filterModes: ['All','Not Answered','Not Rated']
    
    load: (responseId) ->
      svc = @
      @.settings.viewMode = 'loading'
      $http.get('/survey_responses/'+responseId+'.json').then(((resp) ->
        svc.resp = resp.data.survey_response
        svc.settings.viewMode = 'view'
      ))

    addAnswerComment: (answer,content,isPrivate,extraCallback) ->
      promise = $http.post('/answers/'+answer.id+'/answer_comments',{comment:{content:content,private:isPrivate}})
      promise.then(((resp) ->
        answer.answer_comments = [] if answer.answer_comments == undefined
        answer.answer_comments.push resp.data.answer_comment
        extraCallback(answer) if extraCallback
      ), ((resp) ->
        answer.error_message = "There was an error saving your comment. Please reload the page."
      ))

    saveAnswer: (a) ->
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

  }
]

srApp.controller('srController',['$scope','srService',($scope,srService) ->
  $scope.logme = () ->
    console.log 'x'
  $scope.showSubmit = () ->
    $scope.srService.resp.can_submit
  $scope.srService = srService
  $scope.resp = srService.resp
  $scope.addComment = (answer) ->
    $scope.srService.addAnswerComment answer, answer.new_comment, answer.new_comment_private, (a) ->
      a.new_comment = null
      a.new_comment_private = null

  $scope.showWarning = (answer) ->
    return false unless answer.question.warning
    return false if answer.choice && answer.choice.length > 0
    if answer.answer_comments
      for ac in answer.answer_comments
        return false if ac.user.id == $scope.resp.user.id

    true

  $scope.srService.load($scope.response_id) if $scope.response_id
  $scope.$watch 'srService.resp', (newVal,oldVal) ->
    $scope.resp = newVal
  @
])

srApp.filter 'answerFilter', () ->
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
          r.push a
     r

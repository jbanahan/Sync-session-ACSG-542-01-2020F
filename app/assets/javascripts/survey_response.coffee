srApp = angular.module 'SurveyResponseApp', []

srApp.factory 'srService', [() ->
  {
    resp: {
      survey:{
        name:'My Survey'
        rating_values:['Good','Bad']
      }
      answers:[
        {
          id:1
          sort_number:1
          needs_completion:true
          choice:'No'
          rating:'Bad'
          question:{
            id: 2
            html_content: '<em>My Question</em><p>has a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long tex a bunch of long texttttttttttttttt a bunch of long text</p>'
            choices: ['','Yes','No']
            }
          answer_comments: [
            {
              user:{
                full_name:'Brian Glick'
                }
              created_at: '2013-04-21 13:26'
              private: false
              content: 'My Comment'
              }
          ]
        }
      ]
      subtitle:'Survey Label'
      can_rate: true
      can_answer: true
      rating:'Good'
    }
  }
]

srApp.controller('srController',['$scope','srService',($scope,srService) ->
  $scope.srService = srService
  $scope.resp = srService.resp
  $scope.addComment = (answer) ->
    #TODO save here
    answer.answer_comments.push {user:{full_name:'me'},created_at:'time',private:answer.new_comment_private,content:answer.new_comment} if answer.new_comment.length > 0
    answer.new_comment = ''
  $scope.$watch 'srService.resp', (newVal,oldVal) ->
    $scope.resp = newVal
  @
])

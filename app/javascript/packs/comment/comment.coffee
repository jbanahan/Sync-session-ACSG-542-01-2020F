com = angular.module('ChainComments',['ChainComponents','angularMoment']).config(['$httpProvider', ($httpProvider) ->
  $httpProvider.defaults.headers.common['Accept'] = 'application/json'
  $httpProvider.interceptors.push 'chainHttpErrorInterceptor'
])
com.factory 'commentSvc', ['$http', ($http) ->
  return {
    # get the comments for the obj base on the moduleType and it's id parameter and set the obj.comments to an array of the returned comments
    injectComments: (obj, moduleType) ->
      $http.get('/api/v1/comments/for_module/'+moduleType+'/'+obj.id+'.json').then (resp) ->
        obj.comments = resp.data.comments

    addComment: (comment,commentArray) ->
      $http.post('/api/v1/comments.json',{comment: comment}).then (resp) ->
        commentArray.push resp.data.comment

    #delete the comment and remove it from the given (optional) array by id number
    deleteComment: (comment,commentArray) ->
      $http.delete('/api/v1/comments/'+comment.id+'.json').then (resp) ->
        if commentArray
          for c, idx in commentArray
            commentArray.splice(idx,1) if c && c.id == comment.id

  }
]

com.directive 'chainComment', ['commentSvc',(commentSvc) ->
  {
    restrict: 'E'
    scope: {
      parentObject: '='
      moduleType: '@'
    }
    templateUrl: "/partials/comments/chain_comment.html"
    link: (scope, element, attrs) ->
      scope.deleteComment = (c) ->
        c.deleting = true
        commentSvc.deleteComment c, scope.parentObject.comments
      scope.commentToAdd = {}
      scope.addComment = (c) ->
        c.commentable_type = scope.moduleType
        c.commentable_id = scope.parentObject.id
        commentSvc.addComment(c, scope.parentObject.comments).then (resp) ->
          scope.commentToAdd = {}
  }
]

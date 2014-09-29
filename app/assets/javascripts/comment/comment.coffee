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
      $http.post('/api/v1/comments.json',{comment:comment}).then (resp) ->
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
    restrict:'E'
    scope:{
      parentObject:'='
      moduleType:'@'
    }
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
    template:"<div ng-repeat='c in parentObject.comments'>
      <div class='panel panel-default'>
        <div class='panel-heading'>
          <div><div class='pull-right'><abbr am-time-ago='c.created_at' title='{{c.created_at}}'></abbr> {{c.user.full_name}}</div>{{c.subject}}</div>
        </div>
        <div class='panel-body'>
           {{c.body}}
        </div>
        <div class='panel-footer text-right' ng-if='c.permissions.can_delete'>
          <button class='btn btn-sm btn-danger' ng-click='c.deleteCheck=true' ng-hide='c.deleteCheck'>Delete</button>
          <div ng-show='c.deleteCheck && !c.deleting'>
            Are you sure you want to delete this? <button class='btn btn-sm btn-danger' ng-click='deleteComment(c)'>Yes</button>&nbsp;<button class='btn btn-sm btn-default' ng-click='c.deleteCheck=false'>No</button>
          </div>
          <div ng-show='deleting'>Deleting...</div>
        </div>
      </div>
      </div>
      <div class='panel panel-default'>
        <div class='panel-heading'>
          <input type='text' class='form-control' placeholder='Subject' ng-model='commentToAdd.subject' />
        </div>
        <div class='panel-body'>
           <textarea ng-model='commentToAdd.body' class='form-control'></textarea>
        </div>
        <div class='panel-footer text-right'>
          <button class='btn btn-sm btn-default' ng-click='addComment(commentToAdd)' ng-show='commentToAdd.body.length > 0'>Save</button>
        </div>
      </div>"
  }
]
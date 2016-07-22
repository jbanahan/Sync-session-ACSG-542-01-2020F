app = angular.module('Folders', ['ChainFolders'])

app.config ['$httpProvider', ($httpProvider) ->
  $httpProvider.defaults.headers.common['Accept'] = 'application/json'
]

app.controller 'FolderCtrl', ['$scope', ($scope) ->

]
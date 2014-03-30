app = angular.module 'HMApp', []

app.factory 'hmService', ['$http',($http) ->
  hi: 'there'
]

app.controller 'HMPOLineController', ['$scope','hmService',($scope,hmService) ->
  $scope.poLine = {}
]

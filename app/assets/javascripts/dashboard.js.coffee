dashboardApp = angular.module('DashboardApp',['ChainComponents'])
dashboardApp.controller  'DashboardViewController', ['$scope','$http',($scope,$http) ->
  $scope.widget = {}
  $scope.page = 1
  $scope.per_page = 10
  $scope.errors = []
  $scope.notices = []

  $scope.loadWidget = (widgetId) ->
    console.log(widgetId)
    $scope.widget.id = widgetId
]

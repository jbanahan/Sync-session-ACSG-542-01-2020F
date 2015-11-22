app = angular.module('VendorPortal',['ui.router'])

app.config ['$httpProvider', ($httpProvider) ->
  $httpProvider.defaults.headers.common['Accept'] = 'application/json'
]

app.config ['$stateProvider','$urlRouterProvider',($stateProvider,$urlRouterProvider) ->
  $urlRouterProvider.otherwise('/')
  $stateProvider.
    state('main',{
      url: '/'
      templateUrl: "/partials/vendor_portal/main.html"
      controller: ['$scope','$state',($scope,$state) ->
        console.log('routing')
        $scope.world = 'Earth'
      ]
    })
]
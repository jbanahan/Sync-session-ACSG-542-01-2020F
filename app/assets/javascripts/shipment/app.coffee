shipmentApp = angular.module('ShipmentApp', ['ChainComponents','ui.router','ChainComments'])
shipmentApp.config ['$httpProvider', ($httpProvider) ->
  $httpProvider.defaults.headers.common['Accept'] = 'application/json'
  $httpProvider.interceptors.push 'chainHttpErrorInterceptor'
]
shipmentApp.config ['$stateProvider','$urlRouterProvider',($stateProvider,$urlRouterProvider) ->
  $urlRouterProvider.otherwise('/')

  resolveShipmentId = {
    shipmentId: ['$stateParams', ($stateParams) -> $stateParams.shipmentId ]
  }
  $stateProvider.
    state('loading',{templateUrl: '/partials/loading.html'}).
    state('show',{
      url: '/:shipmentId/show'
      templateUrl: '/partials/shipments/show.html'
      controller: 'ShipmentShowCtrl'
      resolve: resolveShipmentId
      }).
    state('process_manifest',{
      abstract: true
      url: '/:shipmentId/process_manifest'
      templateUrl: '/partials/shipments/process_manifest/abstract.html'
      controller: 'ProcessManifestCtrl'
      resolve: resolveShipmentId
      }).
    state('process_manifest.main',{
      url: '/main'
      templateUrl: '/partials/shipments/process_manifest/main.html'
      }).
    state('process_manifest.success',{
      url: '/success'
      templateUrl: '/partials/shipments/process_manifest/success.html'
      }).
    state('add_order', {
      url: '/:shipmentId/add_order'
      templateUrl: '/partials/shipments/add_order.html'
      controller: 'ShipmentAddOrderCtrl'
    }).
    state('book_order', {
      url: '/:shipmentId/book_order'
      templateUrl: '/partials/shipments/book_order.html'
      controller: 'ShipmentBookingCtrl as sbc'
    }).
    state('new',{
      url: '/new'
      templateUrl: '/partials/shipments/new.html'
      controller: 'ShipmentNewCtrl'
      }).
    state('index',{
      url: '/'
      template: ''
      controller: ['$scope','$state',($scope,$state) ->
        if $scope.$root.initId
          $state.go('show',{shipmentId: $scope.$root.initId},{location: 'replace'})
        else if $scope.$root.newShipment
          $state.go('new')
      ]
      })
]
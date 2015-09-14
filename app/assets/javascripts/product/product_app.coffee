productApp = angular.module('ProductApp', ['ChainComponents','ChainDomainer','ui.router'])

# api handling
productApp.config ['$httpProvider', ($httpProvider) ->
  $httpProvider.defaults.headers.common['Accept'] = 'application/json'
  $httpProvider.interceptors.push 'chainHttpErrorInterceptor'
]

# page routing
productApp.config ['$stateProvider','$urlRouterProvider',($stateProvider,$urlRouterProvider) ->
  resolveProductId = {
    productId: ['$stateParams', ($stateParams) ->
      $stateParams.productId
    ]
  }

  $urlRouterProvider.otherwise('/')

  $stateProvider.
    state('index',{
      url: '/'
      template: "<chain-loading-wrapper loading-flag='loading'>"
      controller: ['$scope','$state',($scope,$state) ->
        pId = $("[ng-app='ProductApp'][product-id]").attr('product-id')
        $state.go('show',{productId:pId})
      ]
    }).
    state('show',{
      url: '/:productId/show',
      templateUrl: '/partials/products/show.html'
      controller: 'ShowProductCtrl'
      resolve: resolveProductId
    })
]
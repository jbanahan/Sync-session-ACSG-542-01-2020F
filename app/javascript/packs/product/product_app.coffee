productApp = angular.module('ProductApp', ['ChainComponents','ChainComments','ChainDomainer','CoreObjectValidationResultsApp','ui.router'])

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
  resolveProductAndVariantIds = {
    variantId: ['$stateParams', ($stateParams) ->
      $stateParams.variantId
    ],
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
    }).
    state('show_variant',{
      url: '/:productId/variant/:variantId',
      templateUrl: '/partials/products/show_variant.html',
      controller: 'ShowVariantCtrl',
      resolve: resolveProductAndVariantIds
    })
]
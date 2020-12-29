angular.module('ProductApp').controller 'ShowVariantCtrl', ['$scope','productSvc','variantSvc','chainErrorHandler','chainDomainerSvc','productId','variantId',($scope,productSvc,variantSvc,chainErrorHandler,chainDomainerSvc,productId,variantId) ->

  variantLoadHandler = (resp) ->
    $scope.variant = resp.data.variant
    $scope.loadingFlag = null

  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    $scope.notificationMessage = null

  $scope.product = null
  $scope.dictionary = null
  $scope.variant = null

  $scope.load = (productId, variantId) ->
    $scope.loadingFlag = 'loading'
    chainDomainerSvc.withDictionary().then (dict) ->
      $scope.dictionary = dict
      productSvc.getProduct(productId).then (resp) ->
        $scope.product = resp.data.product
        variantSvc.getVariant(variantId).then variantLoadHandler
          
  $scope.reloadVariant = (productId, variantId) ->
    $scope.loadingFlag = 'loading'
    productSvc.loadProduct(productId).then (resp) ->
      $scope.product = resp.data.product
      variantSvc.loadVariant(variantId).then variantLoadHandler

  $scope.$on 'chain:state-toggle-change:finish', ->
    if $scope.product && $scope.product.id && $scope.variant && $scope.variant.id
      $scope.reloadVariant $scope.product.id, $scope.variant.id

  if productId && variantId
    $scope.load(productId,variantId)
]
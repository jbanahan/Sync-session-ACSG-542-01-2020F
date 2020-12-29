angular.module('ProductApp').directive 'chainVariantPanel', [ '$state', ($state) ->
  restrict: 'E'
  scope: {
    product: '='
    dictionary: '='
  },
  templateUrl: "/partials/products/chain_variant_panel.html",
  link: (scope,el,attrs) ->
    scope.showVariant = (variant) ->
      $state.go('show_variant',{productId:scope.product.id,variantId:variant.id})

]
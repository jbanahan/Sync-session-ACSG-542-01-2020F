angular.module('ProductApp').directive 'chainVariantPanel', [ ->
  restrict: 'E'
  scope: {
    product: '='
  },
  templateUrl: "/partials/products/chain_variant_panel.html"
]
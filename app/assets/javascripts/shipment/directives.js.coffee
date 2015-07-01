shipmentApp = angular.module('ShipmentApp')

shipmentApp.directive 'chainShipDetailSummary', ->
  {
  restrict: 'E'
  scope: {
    shipment: '='
  }
  templateUrl: '/partials/shipments/ship_detail_summary.html'
  }

shipmentApp.directive 'bookingShippingComparison', ->
  {
  restrict: 'E'
  scope: {
    numBooked: '=',
    numShipped: '=',
    name: '@'
  }
  templateUrl: '/partials/shipments/booking_shipping_comparison.html'
  link: (scope) ->
    scope.percentValue = ->
      if scope.numBooked > 0
        Math.floor(((scope.numShipped || 0) / scope.numBooked) * 100)
      else
        100

    return
  }
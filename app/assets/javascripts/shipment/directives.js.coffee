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

shipmentApp.directive 'chainAddressAutocomplete', ->
  restrict: 'E'
  scope:
    initialValue: '='
    selectedObject: '='
    placeholder: '@'
  template: '<angucomplete-alt input-class="form-control" remote-url="/api/v1/addresses/autocomplete?n=" template-url="/partials/shipments/address_modal/address_book_autocomplete_results.html" selected-object="selectedObject" initial-value="{{initialValue}}" placeholder="{{placeholder}}" title-field="name" pause="500"></angucomplete-alt>'

shipmentApp.directive 'addAddressModal', ->
  restrict: 'E'
  scope: {}
  templateUrl:'/partials/shipments/address_modal/add_address_modal.html'
  controllerAs:'ctrl'
  controller:['$http', ($http)->
    @countries = []
    @address = {}

    @createAddress = =>
      console.log @address
      $http.post('/api/v1/addresses',{address: @address}).then => @address = {}
      return

    initCountries = =>
      $http.get('/api/v1/countries').then (resp) =>
        @countries = resp.data

    initCountries()
    return
  ]
  link: (scope, element, attrs) ->
    element.on('show.bs.modal', -> console.log('show'))
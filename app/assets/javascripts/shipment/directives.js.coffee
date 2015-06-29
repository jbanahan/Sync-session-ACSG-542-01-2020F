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

shipmentApp.directive 'addressBookAutocomplete',['addressModalSvc',(addressModalSvc) ->
  restrict: 'E'
  scope:
    initialValue: '='
    selectedObject: '='
    placeholder: '@'
  template: '<angucomplete-alt input-class="form-control" remote-url="/api/v1/addresses/autocomplete?n=" template-url="/partials/shipments/address_modal/address_book_autocomplete_results.html" selected-object="selectedObject" initial-value="{{initialValue}}" placeholder="{{placeholder}}" title-field="name" pause="500"></angucomplete-alt>'
  link:(scope, element, attributes) ->
    addressModalSvc.responders[attributes.selectedObject] = (address) ->
      element.find('input').val(address.name)
      scope.selectedObject = address
]

shipmentApp.directive 'addAddressModal', ['$http', 'addressModalSvc', ($http, addressModalSvc) ->
  restrict: 'E'
  scope: {}
  templateUrl:'/partials/shipments/address_modal/add_address_modal.html'
  controllerAs:'ctrl'
  controller:->
    @countries = []
    @address = {}

    @createAddress = =>
      console.log @address
      $http.post('/api/v1/addresses',{address: @address}).then (resp) =>
        addressModalSvc.onAddressCreated(resp.data.address)
        @address = {}
      return

    initCountries = =>
      $http.get('/api/v1/countries').then (resp) =>
        @countries = resp.data

    initCountries()
    return
  link: (scope, element, attrs) ->
    element.on('show.bs.modal', (event) ->
      if event
        parent = $(event.relatedTarget).parents('address-book-autocomplete')
        if parent && parent.attr
          model = parent.attr('selected-object')
          addressModalSvc.currentResponder = model
    )
]

shipmentApp.service 'addressModalSvc', ->
  @responders = {}
  @onAddressCreated = (address)->
    @responders[@currentResponder](address)
  return
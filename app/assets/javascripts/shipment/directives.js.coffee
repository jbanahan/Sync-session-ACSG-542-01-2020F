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
  template: '<angucomplete-alt input-class="form-control" placeholder="Search Address Book" remote-url="/api/v1/addresses/autocomplete?n=" template-url="/partials/shipments/address_modal/address_book_autocomplete_results.html" selected-object="selectedObject" initial-value="{{initialValue}}" placeholder="{{placeholder}}" title-field="name" description-field="full_address" pause="500"></angucomplete-alt>'
  link:(scope, element, attributes) ->
    selectedObject = attributes.selectedObject
    addressModalSvc.responders[selectedObject] = (address) ->
      element.find('input').val(address.name)
      scope.selectedObject = address

    scope.$on('$destroy', -> delete addressModalSvc.responders[selectedObject])

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

shipmentApp.directive 'addressExpander', ->
  restrict:'E'
  replace:true
  scope:
    title:'@'
    addressName:'='
    fullAddress:'='
  link: (scope, elem, attrs) ->
    scope.rotateChevron = (event) ->
      chevron = $(event.target).find("i.fa-chevron-down")
      if chevron.hasClass("turnup")
        chevron.removeClass("turnup").addClass("turndown")
      else
        chevron.removeClass("turndown").addClass("turnup")
      return true
    scope.notEmptyString = (thing) -> thing && thing.length > 0
  template: '<div class="panel panel-default">
    <div class="panel-heading" role="tab" id="headerOne" ng-click="rotateChevron($event)" data-toggle="collapse" data-parent="#address-accordion" href="#collapse-{{title}}" aria-expanded="false" aria-controls="collapseOne">
        <span ng-style="{color: notEmptyString(addressName) ? \'#a6a6a6\' : \'inherit\' }">{{title}}</span>
        <h4 class="panel-title">
            {{addressName}} <i ng-if="notEmptyString(fullAddress)" class="fa fa-chevron-down pull-right"></i>
        </h4>
    </div>
    <div ng-if="notEmptyString(fullAddress)" id="collapse-{{title}}" role="tabpanel" class="panel-collapse collapse" aria-labelledby="headerOne">
        <div class="panel-body">
            {{fullAddress}}
        </div>
    </div>
</div>'
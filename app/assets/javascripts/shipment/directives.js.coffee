shipmentApp = angular.module('ShipmentApp')

shipmentApp.directive 'chainShipDetailSummary', ->
  {
  restrict: 'E'
  scope: {
    shipment: '='
  }
  templateUrl: '/partials/shipments/ship_detail_summary.html'
  }

shipmentApp.directive 'dateInput', ->
  {
    require: 'ngModel'
    link: (scope, elem, attr, modelCtrl) ->
      modelCtrl.$formatters.push (modelValue) ->
        new Date(modelValue)
      return
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
      numBooked = parseFloat(scope.numBooked)
      numShipped = parseFloat(scope.numShipped)

      if numBooked > 0
        Math.floor(((numShipped || 0) / numBooked) * 100)
      else
        100

    return
  }

shipmentApp.directive 'addressBookAutocomplete',['addressModalSvc',(addressModalSvc) ->
  restrict: 'E'
  scope:
    initialValue: '='
    addressIdAttribute: '='
    shipmentId: '='
  template: '<angucomplete-alt input-class="form-control" placeholder="Search Address Book" remote-url="/api/v1/shipments/{{shipmentId}}/autocomplete_address?n=" template-url="/partials/shipments/address_modal/address_book_autocomplete_results.html" selected-object="onAddressSelected" initial-value="initialValue" placeholder="placeholder" title-field="name" description-field="full_address" pause="500" minlength="2"></angucomplete-alt>'
  link:(scope, element, attributes) ->
    addressIdAttribute = attributes.addressIdAttribute
    addressModalSvc.responders[addressIdAttribute] = (address) ->
      element.find('input').val(address.name)
      scope.addressIdAttribute = address.id

    scope.$on('$destroy', -> delete addressModalSvc.responders[addressIdAttribute])

    scope.onAddressSelected = (address) -> scope.addressIdAttribute = address.originalObject.id if address

]

shipmentApp.directive 'addAddressModal', ['$http', 'addressModalSvc', ($http, addressModalSvc) ->
  restrict: 'E'
  scope:
    shipmentId: '='
  templateUrl:'/partials/shipments/address_modal/add_address_modal.html'
  controllerAs:'ctrl'
  controller: ['$scope',($scope) ->
    @countries = []
    @address = {}

    @createAddress = =>
      $http.post('/api/v1/shipments/' + $scope.shipmentId + '/create_address',{address: @address}).then (resp) =>
        addressModalSvc.onAddressCreated(resp.data.address)
        @address = {}
      return

    initCountries = =>
      $http.get('/api/v1/countries').then (resp) =>
        @countries = resp.data

    initCountries()
    return
  ]
  link: (scope, element, attrs) ->
    element.on('show.bs.modal', (event) ->
      if event
        parent = $(event.relatedTarget).parents('address-book-autocomplete')
        if parent && parent.attr
          model = parent.attr('address-id-attribute')
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
    scope.formattedTitle = attrs.title.replace(/\s/g, '_')
  template: '<div class="card">
    <div class="card-header" role="tab" id="header-{{formattedTitle}}" ng-click="rotateChevron($event)" data-toggle="collapse" data-parent="#address-accordion" href="#collapse-{{formattedTitle}}" aria-expanded="false" aria-controls="collapseOne">
        <span ng-style="{color: notEmptyString(addressName) ? \'#a6a6a6\' : \'inherit\' }">{{title}}</span>
        <h4 class="card-title">
            {{addressName}} <i ng-if="notEmptyString(fullAddress)" class="fa fa-chevron-down float-right"></i>
        </h4>
    </div>
    <div ng-if="notEmptyString(fullAddress)" id="collapse-{{formattedTitle}}" role="tabpanel" class="card-collapse collapse" aria-labelledby="header-{{formattedTitle}}">
        <div class="card-body">
            {{fullAddress}}
        </div>
    </div>
</div>'

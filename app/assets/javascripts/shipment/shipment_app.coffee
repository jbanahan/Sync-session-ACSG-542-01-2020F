shipmentApp = angular.module('ShipmentApp', ['ChainComponents','ui.router','ChainComments'])
shipmentApp.config ['$httpProvider', ($httpProvider) ->
  $httpProvider.defaults.headers.common['Accept'] = 'application/json'
  $httpProvider.interceptors.push 'chainHttpErrorInterceptor'
]
shipmentApp.config ['$stateProvider','$urlRouterProvider',($stateProvider,$urlRouterProvider) ->
  $urlRouterProvider.otherwise('/')

  $stateProvider.
    state('loading',{templateUrl: '/partials/loading.html'}).
    state('show',{
      url: '/:shipmentId/show'
      templateUrl: '/partials/shipments/show.html'
      controller: 'ShipmentShowCtrl'
      resolve: {
        shipmentId: ['$stateParams', ($stateParams) ->
          $stateParams.shipmentId
          ]
        }
      }).
    state('process_manifest',{
      abstract: true
      url: '/:shipmentId/process_manifest'
      templateUrl: '/partials/shipments/process_manifest/abstract.html'
      controller: 'ProcessManifestCtrl'
      resolve: {
        shipmentId: ['$stateParams', ($stateParams) ->
          $stateParams.shipmentId
          ]
        }
      }).
    state('process_manifest.main',{
      url: '/main'
      templateUrl: '/partials/shipments/process_manifest/main.html'
      }).
    state('process_manifest.success',{
      url: '/success'
      templateUrl: '/partials/shipments/process_manifest/success.html'
      }).
    state('add_order', {
      url: '/:shipmentId/add_order'
      templateUrl: '/partials/shipments/add_order.html'
      controller: 'ShipmentAddOrderCtrl'
      resolve: {
        shipmentId: ['$stateParams', ($stateParams) ->
          $stateParams.shipmentId
          ]
        }
    }).
    state('new',{
      url: '/new'
      templateUrl: '/partials/shipments/new.html'
      controller: 'ShipmentNewCtrl'
      }).
    state('index',{
      url: '/'
      template: ''
      controller: ['$scope','$state',($scope,$state) ->
        if $scope.$root.initId
          $state.go('show',{shipmentId: $scope.$root.initId},{location: 'replace'})
        else if $scope.$root.newShipment
          $state.go('new')
      ]
      })
]

shipmentApp.directive 'chainShipDetailSummary', ->
  {
    restrict: 'E'
    scope: {
      shipment: '='
    }
    templateUrl: '/partials/shipments/ship_detail_summary.html'
  }

shipmentApp.controller 'ShipmentNewCtrl', ['$scope','shipmentSvc','$state',($scope,shipmentSvc,$state) ->
  loadParties = ->
    $scope.parties = undefined
    shipmentSvc.getParties().success((data) ->
      $scope.parties = data
    )

  $scope.shp = {}

  $scope.save = (shipment) ->
    $scope.parties = undefined #reset loading flag
    shipmentSvc.saveShipment(shipment).then ((resp) ->
      shipmentSvc.getShipment(resp.data.shipment.id,true).then ->
        $state.go('show',{shipmentId: resp.data.shipment.id})
    ),((resp) ->
      loadParties()
    )


  loadParties()
]
shipmentApp.controller 'ShipmentShowCtrl', ['$scope','shipmentSvc','shipmentId','$state','chainErrorHandler',($scope,shipmentSvc,shipmentId,$state,chainErrorHandler) ->
  loadParties = ->
    $scope.parties = undefined
    shipmentSvc.getParties().success((data) ->
      $scope.parties = data
    )

  bookingAction = (shipment, redoCheckField, actionMethod, namePastTense) ->
    doRequest = true
    if redoCheckField.length > 0
      doRequest = window.confirm("A booking has already been "+namePastTense+". Are you sure you want to do this again?")
    if doRequest
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      actionMethod(shipment).then (resp) ->
        $scope.loadShipment(sId,true).then ->
          window.alert('Booking '+namePastTense+'.')

  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    $scope.notificationMessage = null
  $scope.shp = null
  $scope.loadShipment = (id,forceReload) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getShipment(id,forceReload).then (resp) ->
      $scope.shp = resp.data.shipment
      $scope.loadingFlag = null
      $scope.loadLines($scope.shp) if $scope.linesNeeded

  $scope.loadLines = (shp) ->
    $scope.linesNeeded = true
    shipmentSvc.injectLines shp unless shp.lines

  $scope.edit = ->
    $state.go('edit',{shipmentId: $scope.shp.id})

  $scope.requestBooking = (shipment) ->
    bookingAction(shipment,shipment.shp_booking_received_date,shipmentSvc.requestBooking,'requested')

  $scope.approveBooking = (shipment) ->
    bookingAction(shipment,shipment.shp_booking_approved_date,shipmentSvc.approveBooking,'approved')

  $scope.confirmBooking = (shipment) ->
    bookingAction(shipment,shipment.shp_booking_confirmed_date,shipmentSvc.confirmBooking,'confirmed')

  $scope.reviseBooking = (shipment) ->
    if window.confirm("Revising this booking will remove all approvals and requests. Only do this if you need to add or remove lines.\n\nAre you sure you want to continue?")
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      shipmentSvc.reviseBooking(shipment).then (resp) ->
        $scope.loadShipment(sId,true).then ->
          window.alert('Booking opened for revision.')

  $scope.cancelShipment = (shipment) ->
    if window.confirm("Are you sure you want to cancel this shipment?")
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      shipmentSvc.cancelShipment(shipment).then (resp) ->
        $scope.loadShipment(sId,true).then ->
          window.alert('Shipment canceled.')

  $scope.uncancelShipment = (shipment) ->
    if window.confirm("Are you sure you want to undo canceling this shipment?")
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      shipmentSvc.uncancelShipment(shipment).then (resp) ->
        $scope.loadShipment(sId,true).then ->
          window.alert('Shipment no longer canceled.')

  ###*
  # Takes in a source object and a list of attributes and returns an object containing that subset of the source.
  # In essence, Ruby's Hash#slice in JS
  # The result will have every attribute in the list whether or not they are defined in the source
  #
  # @param {object} source
  # @param {string[]} attributes
  # @return {object}
  ###
  objectSlice = (source={}, attributes=[]) ->
    result = {}
    for attr in attributes
      result[attr] = source[attr]
    result

  ###*
  # Returns a function that takes a source object as a parameter.
  # Slices that object on the provided attributes and assigns the slice to scope under the provided name.
  #
  # @param {string} objName what the object on scope will be called
  # @param {string[]} attributes
  # @return {Function}
  ###
  assignSliceToScopeFn = (objName, attributes) ->
    (source) ->
      $scope[objName] = objectSlice source, attributes

  $scope.prepShipmentHeaderEditObject = assignSliceToScopeFn 'header', ['id',
                                                                        'shp_ref',
                                                                        'shp_importer_reference',
                                                                        'shp_master_bill_of_lading',
                                                                        'shp_house_bill_of_lading',
                                                                        'shp_booking_number',
                                                                        'shp_receipt_location',
                                                                        'shp_dest_port_name',
                                                                        'shp_freight_terms',
                                                                        'shp_lcl',
                                                                        'shp_shipment_type',
                                                                        'shp_vessel',
                                                                        'shp_voyage',
                                                                        'shp_vessel_carrier_scac',
                                                                        'shp_mode',
                                                                        'shp_vessel_name',
                                                                        'shp_vessel_nationality',
                                                                        'shp_first_port_receipt_name',
                                                                        'shp_lading_port_name',
                                                                        'shp_last_foreign_port_name',
                                                                        'shp_unlading_port_name',
                                                                        'shp_marks_and_numbers']

  $scope.prepShipmentLineEditObject = assignSliceToScopeFn 'lineToEdit', ['id',
                                                                         'shpln_shipped_qty',
                                                                         'shpln_carton_qty',
                                                                         'shpln_cbms',
                                                                         'shpln_gross_kgs',
                                                                         'shpln_container_uid']

  $scope.saveLine = (shipment,line) ->
    $scope.saveShipment({id: shipment.id, lines: [line]}).then ->
      $scope.loadLines($scope.shp)

  $scope.deleteLine = (shipment,line) ->
    if window.confirm("Are you sure you want to delete this line?")
      line._destroy = 'true'
      $scope.saveShipment({id: shipment.id, lines: [line]}).then ->
        $scope.loadLines($scope.shp)

  $scope.prepBookingEditObject = assignSliceToScopeFn 'booking', ['id',
                                                                 'shp_booking_cutoff_date',
                                                                 'shp_booking_est_departure_date',
                                                                 'shp_cargo_ready_date',
                                                                 'shp_booking_est_arrival_date',
                                                                 'shp_booking_shipment_type',
                                                                 'shp_booking_mode']

  $scope.prepPartiesEditObject = (shipment) ->
    loadParties() unless $scope.parties
    $scope.partiesEditObj = objectSlice shipment, ['id', 'shp_car_syscode', 'shp_imp_syscode']

  $scope.prepTrackingEditObject = assignSliceToScopeFn 'tracking', ['id',
                                                                   'shp_est_departure_date',
                                                                   'shp_est_arrival_port_date',
                                                                   'shp_est_delivery_date',
                                                                   'shp_docs_received_date',
                                                                   'shp_cargo_on_hand_date',
                                                                   'shp_departure_date',
                                                                   'shp_arrival_port_date',
                                                                   'shp_delivered_date']

  $scope.editContainer = assignSliceToScopeFn 'containerToEdit', ['id',
                                                                 'con_container_number',
                                                                 'con_container_size',
                                                                 'con_seal_number']

  $scope.saveContainer = (shipment,container) ->
    $scope.saveShipment({id: shipment.id, containers: [container]})

  $scope.deleteContainer = (shipment,container) ->
    doAction = window.confirm("Are you sure you want to delete this container?")
    if doAction
      container._destroy = 'true'
      $scope.saveShipment({id: shipment.id, containers: [container]})

  $scope.showProcessManifest = ->
    $state.go('process_manifest.main',{shipmentId: $scope.shp.id})

  $scope.showAddOrder = ->
    $state.go('add_order',{shipmentId: $scope.shp.id})

  $scope.saveShipment = (shipment) ->
    $scope.loadingFlag = 'loading'
    $scope.eh.clear()
    $scope.notificationMessage = "Saving shipment."
    shipmentSvc.saveShipment(shipment).then ((resp) ->
      $scope.loadShipment(shipment.id,true)
    ),((resp) ->
      $scope.loadingFlag = null
    )

  if shipmentId
    $scope.loadShipment shipmentId

]

shipmentApp.controller 'ShipmentAddOrderCtrl', ['$scope','shipmentSvc','shipmentId','$state','chainErrorHandler',($scope,shipmentSvc,shipmentId,$state,chainErrorHandler) ->
  maxVal = (ary,attr,min) ->
    r = min
    for x in ary
      pX = (if x[attr] then parseInt(x[attr]) else min)
      r = pX if pX > r
    r
  $scope.shp = null
  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    $scope.notificationMessage = null

  $scope.prorate = {sign: 'Add', amount: 0}

  $scope.loadShipment = (id) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getShipment(id).then (resp) ->
      $scope.shp = resp.data.shipment
      $scope.loadingFlag = null
      $scope.getAvailableOrders($scope.shp)

  $scope.getAvailableOrders = (shipment) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getAvailableOrders(shipment).then (resp) ->
      $scope.availableOrders = resp.data.available_orders
      $scope.loadingFlag = null

  $scope.getOrder = (order) ->
    $scope.orderLoadingFlag = 'loading'
    $scope.activeOrder = null
    shipmentSvc.getOrder(order.id).then (resp) ->
      $scope.activeOrder = resp.data.order
      $scope.resetQuantityToShip $scope.activeOrder
      $scope.orderLoadingFlag = null

  $scope.resetQuantityToShip = (order) ->
    if order.order_lines
      ln.quantity_to_ship = parseInt(ln.ordln_ordered_qty) for ln in order.order_lines

  $scope.clearQuantityToShip = (order) ->
    if order.order_lines
      ln.quantity_to_ship = 0 for ln in order.order_lines

  $scope.prorate = (order,proration) ->
    percentToChange = parseInt(proration.amount)
    return order if isNaN(percentToChange)
    percentToChange = percentToChange/100
    return order unless order.order_lines
    for ln in order.order_lines
      qty = parseInt(ln.quantity_to_ship)
      if !isNaN(qty)
        amountToChange = Math.floor(percentToChange * qty)
        amountToChange = amountToChange*-1 if proration.sign=='Remove'
        ln.quantity_to_ship = qty + amountToChange
    order
      #create shipment lines for all lines on the given order
  $scope.addOrderToShipment = (shp, ord, container_to_pack) ->
    shp.lines = [] if shp.lines==undefined
    return shp unless ord.order_lines
    for oln in ord.order_lines
      sl = {
        shpln_puid: oln.ordln_puid,
        shpln_pname: oln.ordln_pname,
        linked_order_line_id: oln.id,
        shpln_shipped_qty: oln.quantity_to_ship,
        order_lines: [{ord_cust_ord_no: ord.ord_cust_ord_no,ordln_line_number: oln.ordln_line_number}]
      }
      sl.shpln_container_uid = container_to_pack.id if container_to_pack
      shp.lines.push sl
    shp

  $scope.totalToShip = (ord) ->
    return 0 unless ord && ord.order_lines
    total = 0
    for ln in ord.order_lines
      inc = parseInt(ln.quantity_to_ship)
      total = total + inc unless isNaN(inc)
    total

  $scope.addOrderAndSave = (shp, ord, container_to_pack) ->
    $scope.loadingFlag = 'loading'
    $scope.addOrderToShipment(shp,ord,container_to_pack)
    shipmentSvc.saveShipment(shp).then (resp) ->
      shipmentSvc.getShipment(shp.id,true).then ->
        $state.go('show',{shipmentId: $scope.shp.id})

  $scope.cancel = ->
    $state.go('show',{shipmentId: $scope.shp.id})


  if shipmentId
    $scope.loadShipment shipmentId
]

shipmentApp.controller 'ProcessManifestCtrl', ['$scope','shipmentSvc','shipmentId','$state','chainErrorHandler',($scope,shipmentSvc,shipmentId,$state,chainErrorHandler) ->
  $scope.shp = null
  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    $scope.notificationMessage = null

  $scope.loadShipment = (id) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getShipment(id).then (resp) ->
      $scope.shp = resp.data.shipment
      $scope.loadingFlag = null

  $scope.cancel = ->
    $state.go('edit',{shipmentId: $scope.shp.id})

  $scope.process = (shipment, attachment) ->
    $scope.loadingFlag = 'loading'
    $scope.eh.clear()
    shipmentSvc.processTradecardPackManifest(shipment, attachment).then(((resp) ->
      $scope.loadingFlag = null
      $state.go('process_manifest.success',{shipment: shipment.id})
    ),((resp) ->
      $scope.loadingFlag = null
      )
    )

  if shipmentId
    $scope.loadShipment shipmentId
]

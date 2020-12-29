angular.module('ShipmentApp').controller 'ShipmentAddOrderCtrl', ['$scope','shipmentSvc','$q','$state','chainErrorHandler',($scope,shipmentSvc,$q,$state,chainErrorHandler) ->
  $scope.shp = null
  $scope.eh = chainErrorHandler
  $scope.allLinesEnabled = true
  $scope.eh.responseErrorHandler = (rejection) ->
    $scope.notificationMessage = null

  $scope.proration = {sign: 'Add', amount: 0}

  getAvailableOrders = (shipment) ->
    shipmentSvc.getAvailableOrders(shipment).then (resp) ->
      $scope.availableOrders = resp.data.available_orders

  getBookedOrders = (shipment) ->
    shipmentSvc.getBookedOrders(shipment).then (resp) ->
      $scope.bookedOrders = resp.data.booked_orders
      $scope.linesAvailable = resp.data.lines_available

  $scope.orderSelected = (obj) ->
    if obj
      $scope.getOrderLines(obj.originalObject)


  @loadShipment = (id) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getShipment(id).then (resp) ->
      $scope.shp = resp.data.shipment
      $q.all([
        getAvailableOrders($scope.shp),
        getBookedOrders($scope.shp)
      ]).then -> $scope.loadingFlag = null


  $scope.getOrderLines = (order) ->
    $scope.orderLoadingFlag = 'loading'
    # mysterious hack that prevents order from falling out of scope within the async call (probably due to Angular).
    this_order = angular.copy order
    shipmentSvc.getOrderShipmentRefs(this_order.id).then (resp) ->
      if resp.length > 0
        $scope.orderLoadingFlag = null
        $scope.shipmentWarningModalData = {shipmentsForOrder: resp, orderId: this_order.id}
        $('#shipmentWarningModal').modal 'show'
      else
        $scope.getOrder this_order.id

  $scope.getOrder = (order_id) ->
    $scope.orderLoadingFlag = 'loading'
    $scope.activeOrder = null
    shipmentSvc.getOrder(order_id).then (resp) ->
      $scope.activeOrder = resp.data.order
      $scope.resetQuantityToShip $scope.activeOrder
      $scope.orderLoadingFlag = null

  $scope.clearField = ->
    $('#order_autocomplete_value').val('')
    return true

  $scope.importBooking = ->
    $scope.orderLoadingFlag = 'loading'
    $scope.activeOrder = null
    shipmentSvc.getAvailableLines({id: $state.params.shipmentId}).then (resp) ->
      $scope.activeOrder = {order_lines: resp.data.lines}
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
  $scope.addOrderToShipment = (shp, ord) ->
    shp.lines = [] if shp.lines==undefined
    return shp unless ord.order_lines
    linesToAdd = ord.order_lines.filter((line) -> !line._disabled)
    for oln in linesToAdd
      shp.lines.push
        shpln_puid: oln.ordln_puid,
        shpln_pname: oln.ordln_pname,
        linked_order_line_id: oln.id,
        shpln_shipped_qty: oln.quantity_to_ship,
        shpln_manufacturer_address_id: ord.manufacturerAddressId,
        order_lines: [{ord_cust_ord_no: ord.ord_cust_ord_no || oln.linked_cust_ord_no,ordln_line_number: oln.linked_line_number || oln.ordln_line_number}]
    shp

  $scope.totalToShip = (ord) ->
    return 0 unless ord && ord.order_lines
    total = 0
    for ln in ord.order_lines
      inc = parseInt(ln.quantity_to_ship)
      total = total + inc unless isNaN(inc) or ln._disabled
    total

  goToShow = -> $state.go('show',{shipmentId: $scope.shp.id})

  $scope.addOrderAndSave = (shp, ord, collection) ->
    $scope.loadingFlag = 'loading'
    $scope.addOrderToShipment(shp,ord,collection)
    shipmentSvc.saveShipment(shp).then (resp) ->
      shipmentSvc.getShipment(shp.id,true).then goToShow

  $scope.cancel = goToShow

  $scope.disableAllLines = (order) ->
    for line in order.order_lines
      line._disabled = true
    $scope.allLinesEnabled = false

  $scope.enableAllLines = (order) ->
    for line in order.order_lines
      line._disabled = false
    $scope.allLinesEnabled = true

  @loadShipment $state.params.shipmentId if $state.params.shipmentId

]
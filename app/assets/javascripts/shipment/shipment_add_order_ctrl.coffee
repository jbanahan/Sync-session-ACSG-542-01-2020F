angular.module('ShipmentApp').controller 'ShipmentAddOrderCtrl', ['$scope','shipmentSvc','$state','chainErrorHandler',($scope,shipmentSvc,$state,chainErrorHandler) ->
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

  getAvailableOrders = (shipment) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getAvailableOrders(shipment).then (resp) ->
      $scope.availableOrders = resp.data.available_orders
      $scope.loadingFlag = null

  getBookedOrders = (shipment) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getBookedOrders(shipment).then (resp) ->
      $scope.bookedOrders = resp.data.booked_orders
      $scope.linesAvailable = resp.data.lines_available
      $scope.loadingFlag = null

  loadShipment = (id) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getShipment(id).then (resp) ->
      $scope.shp = resp.data.shipment
      $scope.loadingFlag = null
      getAvailableOrders($scope.shp)
      getBookedOrders($scope.shp)


  $scope.getOrder = (order) ->
    $scope.orderLoadingFlag = 'loading'
    $scope.activeOrder = null
    shipmentSvc.getOrder(order.id).then (resp) ->
      $scope.activeOrder = resp.data.order
      $scope.resetQuantityToShip $scope.activeOrder
      $scope.orderLoadingFlag = null

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
  $scope.addOrderToShipment = (shp, ord, collection_name) ->
    makeLineObj = (oln)->
      if collection_name == 'booking_lines'
        {
        bkln_order_line_id: oln.id,
        bkln_quantity: oln.quantity_to_ship,
        }
      else
        {
        shpln_puid: oln.ordln_puid,
        shpln_pname: oln.ordln_pname,
        linked_order_line_id: oln.id,
        shpln_shipped_qty: oln.quantity_to_ship,
        order_lines: [{ord_cust_ord_no: ord.ord_cust_ord_no || oln.linked_cust_ord_no,ordln_line_number: oln.linked_line_number || oln.ordln_line_number}]
        }

    shp[collection_name] = [] if shp[collection_name]==undefined
    return shp unless ord.order_lines
    for oln in ord.order_lines
      sl = makeLineObj oln
      shp[collection_name].push sl
    shp

  $scope.totalToShip = (ord) ->
    return 0 unless ord && ord.order_lines
    total = 0
    for ln in ord.order_lines
      inc = parseInt(ln.quantity_to_ship)
      total = total + inc unless isNaN(inc)
    total

  goToShow = -> $state.go('show',{shipmentId: $scope.shp.id})

  $scope.addOrderAndSave = (shp, ord, collection) ->
    $scope.loadingFlag = 'loading'
    $scope.addOrderToShipment(shp,ord,collection)
    shipmentSvc.saveShipment(shp).then (resp) ->
      shipmentSvc.getShipment(shp.id,true).then goToShow

  $scope.cancel = goToShow

  if $state.params.shipmentId
    loadShipment $state.params.shipmentId
]
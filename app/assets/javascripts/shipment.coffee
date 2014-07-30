shipmentApp = angular.module('ShipmentApp', ['ChainComponents'])
shipmentApp.config(['$httpProvider', ($httpProvider) ->
  $httpProvider.defaults.headers.common['Accept'] = 'application/json';
])
shipmentApp.factory 'shipmentSvc', ['$http',($http) ->
  maxVal = (ary,attr,min) ->
    r = min
    for x in ary
      pX = (if x[attr] then parseInt(x[attr]) else min)
      r = pX if pX > r
    r
  prepForSave = (shipment) ->
    updatedLines = []
    if shipment.lines
      for ln in shipment.lines
        qty = parseFloat(ln.shpln_shipped_qty)
        if ln.id
          if !qty || qty==0
            ln._destroy = true
          updatedLines.push ln
        else
          updatedLines.push ln if qty && qty>0
      shipment.lines = updatedLines
    shipment

  return {
    getShipment: (shipmentId) ->
      $http.get('/api/v1/shipments/'+shipmentId+'.json?include=order_lines')
    saveShipment: (shipment) ->
      s = prepForSave shipment
      if shipment.id && shipment.id > 0
        $http.put('/api/v1/shipments/'+s.id+'.json',{shipment: s, include:'order_lines'})
      else
        $http.post('/api/v1/shipments',{shipment: s, include:'order_lines'})
    getParties: ->
      $http.get('/api/v1/companies?roles=importer,carrier')
    getAvailableOrders : (page) ->
      $http.get('/api/v1/orders?fields=ord_ord_num,ord_ven_name&page='+page)
    getOrder: (id) ->
      $http.get('/api/v1/orders/'+id)
    #create shipment lines for all lines on the given order
    addOrderToShipment: (shp, ord, container_to_pack) ->
      shp.lines = [] if shp.lines==undefined
      nextLineNumber = maxVal(shp.lines,'shpln_line_number',0) + 1
      return shp unless ord.lines
      for oln in ord.lines
        sl = {
          shpln_line_number:nextLineNumber,
          shpln_puid:oln.ordln_puid,
          shpln_pname:oln.ordln_pname,
          linked_order_line_id:oln.id,
          order_lines:[{ord_cust_ord_no:ord.ord_cust_ord_no,ordln_line_number:oln.ordln_line_number}]
        }
        sl.shpln_container_uid = container_to_pack.id if container_to_pack
        shp.lines.push sl
        nextLineNumber = nextLineNumber + 1
      shp
  }
]

shipmentApp.controller 'ShipmentCtrl', ['$scope','shipmentSvc',($scope,shipmentSvc) ->
  $scope.shp = null
  $scope.loading = false
  $scope.viewMode = 'shp'
  $scope.errorMessage = null
  $scope.notificationMessage = null

  $scope.init = (id) ->
    $scope.loadShipment(id)
    $scope.loadParties()

  $scope.loadParties = ->
    $scope.loadingParties = true
    shipmentSvc.getParties().success((data) ->
      $scope.parties = data
      $scope.loadingParties = false
    ).error((data) ->
      $scope.errorMessage = data.errors.join("<br />")
      $scope.loadingParties = false
    )
  $scope.loadShipment = (id) ->
    $scope.loading = true
    shipmentSvc.getShipment(id).success((data) ->
      $scope.shp = data.shipment
      $scope.loading = false
      $scope.hasNewContainer = false
    ).error((data) ->
      $scope.errorMessage = data.errors.join("<br />")
      $scope.loading = false
    )

  $scope.saveShipment = (shipment) ->
    $scope.loading = true
    $scope.notificationMessage = "Saving shipment."
    shipmentSvc.saveShipment(shipment).success((data) ->
      $scope.shp = data.shipment
      $scope.loading = false
      $scope.notificationMessage = "Shipment saved."
      $scope.hasNewContainer = false
    ).error((data) ->
      $scope.errorMessage = data.errors.join("<br />")
      $scope.loading = false
    )

  $scope.addContainer = (shipment) ->
    $scope.hasNewContainer = true
    shipment.containers = [] unless shipment.containers
    shipment.containers.push({isNew:true})

  $scope.enableOrderSelection = ->
    $scope.viewMode = "ord"
    $scope.availableOrders = null
    shipmentSvc.getAvailableOrders(1).success((data) ->
      $scope.availableOrders = data.results
    ).error((data) ->
      $scope.errorMessage = data.errors.join("<br />")
    )

  $scope.addOrder = (shp,ord,container_to_pack) ->
    shipmentSvc.getOrder(ord.id).success((data) ->
      fullOrder = data.order
      shipmentSvc.addOrderToShipment(shp,fullOrder,container_to_pack)
      $scope.viewMode = 'shp'
      $scope.notificationMessage = 'Order added.'
    ).error((data) ->
      $scope.errorMessage = data.errors.join("<br />")
    )
]
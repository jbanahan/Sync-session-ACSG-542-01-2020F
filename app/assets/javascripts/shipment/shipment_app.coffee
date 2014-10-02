shipmentApp = angular.module('ShipmentApp', ['ChainComponents','ui.router','ChainComments'])
shipmentApp.config ['$httpProvider', ($httpProvider) ->
  $httpProvider.defaults.headers.common['Accept'] = 'application/json';
  $httpProvider.interceptors.push 'chainHttpErrorInterceptor'
]
shipmentApp.config ['$stateProvider','$urlRouterProvider',($stateProvider,$urlRouterProvider) ->
  $urlRouterProvider.otherwise('/')

  $stateProvider.
    state('loading',{templateUrl:'/partials/loading.html'}).
    state('show',{
      url:'/:shipmentId/show'
      templateUrl:'/partials/shipments/show.html'
      controller:'ShipmentShowCtrl'
      resolve:{
        shipmentId: ['$stateParams', ($stateParams) ->
          $stateParams.shipmentId
          ]
        }
      }).
    state('edit',{
      url:'/:shipmentId/edit'
      templateUrl:'/partials/shipments/edit.html'
      controller:'ShipmentEditCtrl'
      resolve:{
        shipmentId: ['$stateParams', ($stateParams) ->
          $stateParams.shipmentId
          ]
        }
      }).
    state('process_manifest',{
      abstract:true
      url:'/:shipmentId/process_manifest'
      templateUrl:'/partials/shipments/process_manifest/abstract.html'
      controller:'ProcessManifestCtrl'
      resolve:{
        shipmentId: ['$stateParams', ($stateParams) ->
          $stateParams.shipmentId
          ]
        }
      }).
    state('process_manifest.main',{
      url:'/main'
      templateUrl:'/partials/shipments/process_manifest/main.html'
      }).
    state('process_manifest.success',{
      url:'/success'
      templateUrl:'/partials/shipments/process_manifest/success.html'
      }).
    state('add_order', {
      url:'/:shipmentId/add_order'
      templateUrl:'/partials/shipments/add_order.html'
      controller:'ShipmentAddOrderCtrl'
      resolve:{
        shipmentId: ['$stateParams', ($stateParams) ->
          $stateParams.shipmentId
          ]
        }
    }).
    state('new',{
      url:'/new'
      templateUrl:'/partials/shipments/edit.html'
      controller:'ShipmentEditCtrl'
      resolve:{
        shipmentId: ['$stateParams', ($stateParams) ->
          -1
          ]
        }
      }).
    state('index',{
      url:'/'
      template:''
      controller:['$scope','$state',($scope,$state) ->
        if $scope.$root.initId
          $state.go('show',{shipmentId:$scope.$root.initId},{location:'replace'}) 
        else if $scope.$root.newShipment
          $state.go('new')
      ]
      })
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

  $scope.prorate = {sign:'Add',amount:0}

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
    if order.lines
      ln.quantity_to_ship = ln.ordln_ordered_qty for ln in order.lines

  $scope.clearQuantityToShip = (order) ->
    if order.lines
      ln.quantity_to_ship = 0 for ln in order.lines

  $scope.prorate = (order,proration) ->
    percentToChange = parseInt(proration.amount)
    return order if isNaN(percentToChange)
    percentToChange = percentToChange/100
    return order unless order.lines
    for ln in order.lines
      qty = parseInt(ln.quantity_to_ship)
      if !isNaN(qty)
        amountToChange = Math.floor(percentToChange * qty)
        amountToChange = amountToChange*-1 if proration.sign=='Remove'
        ln.quantity_to_ship = qty + amountToChange
    order
      #create shipment lines for all lines on the given order
  $scope.addOrderToShipment = (shp, ord, container_to_pack) ->
    shp.lines = [] if shp.lines==undefined
    nextLineNumber = maxVal(shp.lines,'shpln_line_number',0) + 1
    return shp unless ord.lines
    for oln in ord.lines
      sl = {
        shpln_line_number:nextLineNumber,
        shpln_puid:oln.ordln_puid,
        shpln_pname:oln.ordln_pname,
        linked_order_line_id:oln.id,
        shpln_shipped_qty:oln.quantity_to_ship,
        order_lines:[{ord_cust_ord_no:ord.ord_cust_ord_no,ordln_line_number:oln.ordln_line_number}]
      }
      sl.shpln_container_uid = container_to_pack.id if container_to_pack
      shp.lines.push sl
      nextLineNumber = nextLineNumber + 1
    shp

  $scope.totalToShip = (ord) ->
    return 0 unless ord && ord.lines
    total = 0
    for ln in ord.lines
      inc = parseInt(ln.quantity_to_ship)
      total = total + inc unless isNaN(inc)
    total

  $scope.addOrderAndSave = (shp, ord, container_to_pack) ->
    $scope.loadingFlag = 'loading'
    $scope.addOrderToShipment(shp,ord,container_to_pack)
    shipmentSvc.saveShipment(shp).then (resp) ->
      $state.go('edit',{shipmentId:$scope.shp.id})

  $scope.cancel = () ->
    $state.go('edit',{shipmentId:$scope.shp.id})


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

  $scope.cancel = () ->
    $state.go('edit',{shipmentId:$scope.shp.id})

  $scope.process = (shipment, attachment) ->
    $scope.loadingFlag = 'loading'
    $scope.eh.clear()
    shipmentSvc.processTradecardPackManifest(shipment, attachment).then(((resp) ->
      $scope.loadingFlag = null
      $state.go('process_manifest.success',{shipment:shipment.id})
    ),((resp) ->
      $scope.loadingFlag = null
      )
    )

  if shipmentId
    $scope.loadShipment shipmentId  
]

shipmentApp.controller 'ShipmentShowCtrl', ['$scope','shipmentSvc','shipmentId','$state','chainErrorHandler',($scope,shipmentSvc,shipmentId,$state,chainErrorHandler) ->
  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    $scope.notificationMessage = null
  $scope.shp = null
  $scope.hideComments = true
  $scope.loadShipment = (id) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getShipment(id).then (resp) ->
      $scope.shp = resp.data.shipment
      $scope.loadingFlag = null

  $scope.edit = () ->
    $state.go('edit',{shipmentId:$scope.shp.id})

  if shipmentId
    $scope.loadShipment shipmentId

]

shipmentApp.controller 'ShipmentEditCtrl', ['$scope','$state','shipmentSvc','chainErrorHandler','shipmentId',($scope,$state,shipmentSvc,chainErrorHandler,shipmentId) ->
  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    $scope.notificationMessage = null
  $scope.shipmentSvc = shipmentSvc #only here for debugging
  $scope.shp = null
  $scope.viewMode = 'shp'
  $scope.errorMessage = null
  $scope.notificationMessage = null

  $scope.init = (id) ->
    $scope.loadShipment(id) if id
    $scope.loadParties()

  $scope.loadParties = ->
    $scope.loadingParties = true
    shipmentSvc.getParties().success((data) ->
      $scope.parties = data
      $scope.loadingParties = false
    ).error((data) ->
      $scope.loadingParties = false
    )
  $scope.loadShipment = (id) ->
    $scope.loadingFlag = 'loading'
    $scope.eh.clear()
    p = shipmentSvc.getShipment(id)
    p.then((resp) ->
      $scope.shp = resp.data.shipment
      $scope.hasNewContainer = false
      $scope.loadingFlag = null
    )

  $scope.cancel = () ->
    $scope.loadingFlag = 'loading'
    $scope.eh.clear()
    shipmentSvc.getShipment($scope.shp.id,true).then((resp) ->
      $state.go('show',{shipmentId:$scope.shp.id})
    )    

  $scope.saveShipment = (shipment) ->
    $scope.loadingFlag = 'loading'
    $scope.eh.clear()
    $scope.notificationMessage = "Saving shipment."
    shipmentSvc.saveShipment(shipment).then ((resp) ->
      $scope.shp = resp.data.shipment
      $scope.loadingFlag = null
      $scope.notificationMessage = "Shipment saved."
      $scope.hasNewContainer = false
    ),((resp) ->
      $scope.loadingFlag = null
    )

  $scope.addContainer = (shipment) ->
    $scope.hasNewContainer = true
    shipment.containers = [] unless shipment.containers
    shipment.containers.push({isNew:true})

  $scope.showProcessManifest = () ->
    $state.go('process_manifest.main',{shipmentId:$scope.shp.id})

  $scope.showAddOrder = () ->
    $state.go('add_order',{shipmentId:$scope.shp.id})

  $scope.$watch('eh.errorMessage',(nv,ov) ->
    $scope.errorMessage = nv
  )

  if shipmentId==-1
    $scope.shp = {permissions:{can_edit:true,can_view:true,can_attach:true}}
    $scope.init()
  else if shipmentId
    $scope.init(shipmentId) 
]
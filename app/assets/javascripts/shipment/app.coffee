shipmentApp = angular.module('ShipmentApp', ['ChainComponents','ui.router'])
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
    state('edit.select_order',{url:'/select_order',templateUrl:'/partials/shipments/select_order.html'}).
    state('index',{
      url:'/'
      template:''
      controller:['$scope','$state',($scope,$state) ->
        if $scope.$root.initId
          $state.go('show',{shipmentId:$scope.$root.initId}) 
        else if $scope.$root.newShipment
          $state.go('new')
      ]
      })
]

shipmentApp.controller 'ProcessManifestCtrl', ['$scope','shipmentSvc','shipmentId','$state',($scope,shipmentSvc,shipmentId,$state) ->
  $scope.shp = null
  $scope.loadShipment = (id) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getShipment(id).then (resp) ->
      $scope.shp = resp.data.shipment
      $scope.loadingFlag = null

  $scope.cancel = () ->
    $state.go('edit',{shipmentId:$scope.shp.id})

  $scope.process = (shipment, attachment) ->
    shipmentSvc.processTradecardPackManifest(shipment, attachment)

  if shipmentId
    $scope.loadShipment shipmentId  
]

shipmentApp.controller 'ShipmentShowCtrl', ['$scope','shipmentSvc','shipmentId','$state',($scope,shipmentSvc,shipmentId,$state) ->
  $scope.shp = null
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
    $scope.loadShipment(id)
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
    shipmentSvc.getShipment(id).then((resp) ->
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
    $scope.loading = true
    $scope.eh.clear()
    $scope.notificationMessage = "Saving shipment."
    shipmentSvc.saveShipment(shipment).success((data) ->
      $scope.shp = data.shipment
      $scope.loading = false
      $scope.notificationMessage = "Shipment saved."
      $scope.hasNewContainer = false
    ).error((data) ->
      $scope.loading = false
    )

  $scope.addContainer = (shipment) ->
    $scope.hasNewContainer = true
    shipment.containers = [] unless shipment.containers
    shipment.containers.push({isNew:true})

  $scope.enableOrderSelection = ->
    # $state.go('loading')
    $scope.availableOrders = null
    shipmentSvc.getAvailableOrders(1).success((data) ->
      $scope.availableOrders = data.results
      # $state.go('select_order')
    )

  $scope.addOrder = (shp,ord,container_to_pack) ->
    shipmentSvc.getOrder(ord.id).success((data) ->
      fullOrder = data.order
      shipmentSvc.addOrderToShipment(shp,fullOrder,container_to_pack)
      $scope.viewMode = 'shp'
      $scope.notificationMessage = 'Order added.'
    )

  $scope.$watch('eh.errorMessage',(nv,ov) ->
    $scope.errorMessage = nv
  )

  if shipmentId==-1
    $scope.shp = {permissions:{can_edit:true,can_view:true,can_attach:true}}
  else if shipmentId
    $scope.init(shipmentId) 
]
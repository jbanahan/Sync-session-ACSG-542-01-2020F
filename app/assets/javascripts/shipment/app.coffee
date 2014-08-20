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
          $state.go('show',{shipmentId:$scope.$root.initId}) 
        else if $scope.$root.newShipment
          $state.go('new')
      ]
      })
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
    $scope.loading = true
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
    console.log('pm')
    $state.go('process_manifest.main',{shipmentId:$scope.shp.id})

  $scope.$watch('eh.errorMessage',(nv,ov) ->
    $scope.errorMessage = nv
  )

  if shipmentId==-1
    $scope.shp = {permissions:{can_edit:true,can_view:true,can_attach:true}}
  else if shipmentId
    $scope.init(shipmentId) 
]
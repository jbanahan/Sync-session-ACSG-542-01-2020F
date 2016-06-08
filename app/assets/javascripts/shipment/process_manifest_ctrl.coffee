angular.module('ShipmentApp').controller 'ProcessManifestCtrl', ['$scope','shipmentSvc','$state','chainErrorHandler','$window',($scope,shipmentSvc,$state,chainErrorHandler, $window) ->
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
    $state.go('show',{shipmentId: $scope.shp.id})

  $scope.process = (shipment, attachment, attachmentType) ->
    $scope.loadingFlag = 'loading'
    $scope.eh.clear()
    if attachmentType == 'Booking Worksheet'
      handler = shipmentSvc.processBookingWorksheet
    else if attachmentType == 'Tradecard Manifest'
      handler = shipmentSvc.processTradecardPackManifest
    else if attachmentType == 'Manifest Worksheet'
      handler = shipmentSvc.processManifestWorksheet
    else
      $window.alert("Unknown worksheet type " + attachmentType + " selected.")
      $state.go('show', {shipmentId: shipment.id})

    if handler
      handler(shipment, attachment, shipment.manufacturerId).then((resp) ->
        $state.go('process_manifest.success')
      ).finally -> $scope.loadingFlag = null

  if $state.params.shipmentId
    $scope.loadShipment $state.params.shipmentId
]
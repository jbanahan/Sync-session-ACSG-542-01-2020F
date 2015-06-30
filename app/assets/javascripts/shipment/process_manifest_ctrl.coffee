angular.module('ShipmentApp').controller 'ProcessManifestCtrl', ['$scope','shipmentSvc','shipmentId','$state','chainErrorHandler',($scope,shipmentSvc,shipmentId,$state,chainErrorHandler) ->
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
    handler = if $scope.attachmentType == 'Booking Worksheet' then shipmentSvc.processBookingWorksheet else shipmentSvc.processTradecardPackManifest
    handler(shipment, attachment).then((resp) ->
      $state.go('process_manifest.success',{shipment: shipment.id})
    ).finally -> $scope.loadingFlag = null

  if shipmentId
    $scope.loadShipment shipmentId
]
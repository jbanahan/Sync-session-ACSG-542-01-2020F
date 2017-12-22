angular.module('ShipmentApp').controller 'ProcessManifestCtrl', ['$scope','shipmentSvc','$state','chainErrorHandler','$window',($scope,shipmentSvc,$state,chainErrorHandler, $window) ->
  $scope.shp = null
  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    error = rejection.data.errors[0]
    if /ORDERS FOUND/.exec(error)
      @.clear()
      msgJSON = JSON.parse(error.split("~")[1])
      $scope.warningModalMsg = $scope.formatMultiShipmentError msgJSON
      $('#shipmentWarningModal').modal 'show'
    $scope.notificationMessage = null

  $scope.formatMultiShipmentError = (errJson) ->
    segments = []
    for ordNum,refs of errJson
      for r in refs
        segments.push "#{ordNum} (#{r})"
    segments.join(", ")

  $scope.confirmCancel = ->
    setTimeout ->
      $window.alert("All processing has been cancelled")
    , 500

  $scope.loadShipment = (id) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getShipment(id).then (resp) ->
      $scope.shp = resp.data.shipment
      $scope.loadingFlag = null

  $scope.cancel = ->
    $state.go('show',{shipmentId: $scope.shp.id})

  $scope.process = (shipment, attachment, attachmentType, checkOrders) ->
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
      handler(shipment, attachment, shipment.manufacturerId, checkOrders).then((resp) ->
        $state.go('process_manifest.success')
      ).finally -> $scope.loadingFlag = null

  if $state.params.shipmentId
    $scope.loadShipment $state.params.shipmentId
]
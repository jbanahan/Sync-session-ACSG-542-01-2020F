angular.module('ShipmentApp').controller 'ProcessManifestCtrl', ['$scope','shipmentSvc','$state','chainErrorHandler','$window',($scope,shipmentSvc,$state,chainErrorHandler, $window) ->
  $scope.shp = null
  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    error = rejection.data.errors[0]
    if /ORDERS FOUND/.exec(error)
      @.clear()
      $scope.warningModalMsg = $scope.formatErrors error
      $('#shipmentWarningModal').modal 'show'
    $scope.notificationMessage = null

  $scope.formatErrors = (error) ->
    messages = {}
    for i in error.split("*")
      [k, v] = i.split("~")
      messages[$scope.errLookup k] = JSON.parse v
    messages["other_shipments"] = $scope.formatMultiShipmentError(messages["other_shipments"]) if messages["other_shipments"]
    messages["transport_mode"] = messages["transport_mode"].join(", ") if messages["transport_mode"]
    messages

  $scope.errLookup = (k) ->
    l = {"ORDERS FOUND ON MULTIPLE SHIPMENTS: " : "other_shipments", "ORDERS FOUND WITH MISMATCHED MODE: " : "transport_mode"}
    l[k]

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

  $scope.process = (shipment, attachment, attachmentType, enableWarnings) ->
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
      handler(shipment, attachment, shipment.manufacturerId, enableWarnings).then((resp) ->
        $state.go('process_manifest.success')
      ).finally -> $scope.loadingFlag = null

  if $state.params.shipmentId
    $scope.loadShipment $state.params.shipmentId
]

angular.module('ShipmentApp').controller 'ProcessManifestCtrl', ['$scope','shipmentSvc','$state','chainErrorHandler','$window',($scope,shipmentSvc,$state,chainErrorHandler, $window) ->
  $scope.shp = null
  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    error = rejection.data.errors[0]
    if /The following purchase orders/.exec(error)
      @.clear()
      $scope.warningModalMsgs = error.split(" *** ")
      $('#shipmentWarningModal').modal 'show'
    $scope.notificationMessage = null

  $scope.errLookup = (k) ->
    l = {"Orders found on multiple shipments: " : "other_shipments", "Orders found with mismatched mode: " : "transport_mode"}
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
      $scope.notices = resp.data.notices || []
      $scope.warningModalMsgs = []
      $scope.shp = resp.data.shipment
      $scope.selector = 
        availableAttachments: $scope.shp.attachments.slice(0), 
        attachmentsToAdd: [], 
        attachmentsToRemove: [], 
        processAttachments: []
      $scope.loadingFlag = null

  $scope.cancel = ->
    $state.go('show',{shipmentId: $scope.shp.id})

  $scope.process = (shipment, attachments, attachmentType, enableWarnings) ->
    $scope.loadingFlag = 'loading'
    $scope.eh.clear()
    $scope.notices = []
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
      att_ids = (att.id for att in attachments)
      handler(shipment, att_ids, shipment.manufacturerId, enableWarnings).then((resp) ->
        if att_ids.length > 1
          data = resp["data"]
          $scope.notices = data["notices"] if data
        else
          $state.go('process_manifest.success')
      ).finally -> $scope.loadingFlag = null

  $scope.add = () ->
    $scope.moveSelectionToModel($scope.selector.processAttachments, $scope.selector.availableAttachments, $scope.selector.attachmentsToAdd)

  $scope.remove = () ->
    $scope.moveSelectionToModel($scope.selector.availableAttachments, $scope.selector.processAttachments, $scope.selector.attachmentsToRemove)

  #add the selected model field uids to the given array in the model
  $scope.moveSelectionToModel = (toArray, fromArray, selectionArray) ->
    for attachment in selectionArray
      toArray.push attachment
      idx = fromArray.indexOf(attachment)
      fromArray.splice(idx, 1)
    selectionArray.splice(0)

  if $state.params.shipmentId
    $scope.loadShipment $state.params.shipmentId
]

angular.module('ShipmentApp').controller 'ShipmentShowCtrl', ['$scope','shipmentSvc','$state','chainErrorHandler',($scope,shipmentSvc,$state,chainErrorHandler) ->
  loadParties = ->
    $scope.parties = undefined
    shipmentSvc.getParties().success((data) ->
      $scope.parties = data
    )

  bookingAction = (shipment, redoCheckField, actionMethod, namePastTense) ->
    doRequest = true
    if redoCheckField.length > 0
      doRequest = window.confirm("A booking has already been "+namePastTense+". Are you sure you want to do this again?")
    if doRequest
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      actionMethod(shipment).then (resp) ->
        $scope.loadShipment(sId,true).then ->
          window.alert('Booking '+namePastTense+'.')

  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    $scope.notificationMessage = null
  $scope.shp = null
  $scope.loadShipment = (id,forceReload) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getShipment(id,forceReload).then (resp) ->
      $scope.shp = resp.data.shipment
      $scope.loadingFlag = null
      $scope.loadShipmentLines($scope.shp) if $scope.shipmentLinesNeeded
      $scope.loadBookingLines($scope.shp) if $scope.bookingLinesNeeded

  $scope.loadShipmentLines = (shp) ->
    $scope.shipmentLinesNeeded = true
    shipmentSvc.injectShipmentLines shp unless shp.lines

  $scope.loadBookingLines = (shp) ->
    $scope.bookingLinesNeeded = true
    shipmentSvc.injectBookingLines shp unless shp.booking_lines

  $scope.requestBooking = (shipment) ->
    bookingAction(shipment,shipment.shp_booking_received_date,shipmentSvc.requestBooking,'requested')

  $scope.approveBooking = (shipment) ->
    bookingAction(shipment,shipment.shp_booking_approved_date,shipmentSvc.approveBooking,'approved')

  $scope.confirmBooking = (shipment) ->
    bookingAction(shipment,shipment.shp_booking_confirmed_date,shipmentSvc.confirmBooking,'confirmed')

  $scope.reviseBooking = (shipment) ->
    if window.confirm("Revising this booking will remove all approvals and requests. Only do this if you need to add or remove lines.\n\nAre you sure you want to continue?")
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      shipmentSvc.reviseBooking(shipment).then (resp) ->
        $scope.loadShipment(sId,true).then ->
          window.alert('Booking opened for revision.')

  $scope.requestCancel = (shipment) ->
    if window.confirm("Are you sure you want to request to cancel this shipment?")
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      shipmentSvc.requestCancel(shipment).then (resp) ->
        $scope.loadShipment(sId,true).then ->
          window.alert('Request sent.')

  $scope.cancelShipment = (shipment) ->
    if window.confirm("Are you sure you want to cancel this shipment?")
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      shipmentSvc.cancelShipment(shipment).then (resp) ->
        $scope.loadShipment(sId,true).then ->
          window.alert('Shipment canceled.')

  $scope.uncancelShipment = (shipment) ->
    if window.confirm("Are you sure you want to undo canceling this shipment?")
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      shipmentSvc.uncancelShipment(shipment).then (resp) ->
        $scope.loadShipment(sId,true).then ->
          window.alert('Shipment no longer canceled.')

  ###*
  # Takes in a source object and a list of attributes and returns an object containing that subset of the source.
  # In essence, Ruby's Hash#slice in JS
  # The result will have every attribute in the list whether or not they are defined in the source
  #
  # @param {object} source
  # @param {string[]} attributes
  # @return {object}
  ###
  objectSlice = (source={}, attributes=[]) ->
    result = {}
    for attr in attributes
      result[attr] = source[attr]
    result

  ###*
  # Returns a function that takes a source object as a parameter.
  # Copies that object and assigns the copy to scope under the provided name.
  #
  # @param {string} objName
  # @return {Function}
  ###
  copyObjectToScopeAs = (objName) ->
    (source) ->
      $scope[objName] = angular.copy(source)

  $scope.prepShipmentHeaderEditObject = copyObjectToScopeAs 'header'

  $scope.prepShipmentLineEditObject = copyObjectToScopeAs 'lineToEdit'

  ###*
  # Generic function to save a line
  #
  # @param {number|string} id The shipment ID
  # @param {object} line The shipment or booking line to save
  # @param {string} attr_name Which attribute the line should be assigned to
  ###
  saveLine = (id,line,attr_name) ->
    data = {}
    data.id = id
    data[attr_name] = [line]
    $scope.saveShipment data

  saveShipmentLine = (shipment,line) -> saveLine(shipment.id, line, 'lines')
  saveBookingLine = (shipment,line) -> saveLine(shipment.id, line, 'booking_lines')

  $scope.saveShipmentLine = (shipment,line) ->
    saveShipmentLine(shipment,line).then ->
      $scope.loadShipmentLines($scope.shp)

  $scope.deleteShipmentLine = (shipment,line) ->
    if window.confirm("Are you sure you want to delete this line?")
      line._destroy = 'true'
      saveShipmentLine(shipment,line).then ->
        $scope.loadShipmentLines($scope.shp)

  $scope.saveBookingLine = (shipment,line) ->
    saveBookingLine(shipment,line).then ->
      $scope.loadBookingLines($scope.shp)

  $scope.deleteBookingLine = (shipment,line) ->
    if window.confirm("Are you sure you want to delete this line?")
      line._destroy = 'true'
      saveBookingLine(shipment,line).then ->
        $scope.loadBookingLines($scope.shp)

  $scope.prepBookingEditObject = copyObjectToScopeAs 'booking'

  $scope.prepPartiesEditObject = (shipment) ->
    loadParties() unless $scope.parties
    $scope.partiesEditObj = objectSlice shipment, ['id', 'shp_car_syscode', 'shp_imp_syscode']

  $scope.prepTrackingEditObject = copyObjectToScopeAs 'tracking'

  $scope.prepDelayReasonObject = copyObjectToScopeAs 'delay'

  $scope.editContainer = copyObjectToScopeAs 'containerToEdit'

  $scope.saveContainer = (shipment,container) ->
    $scope.saveShipment({id: shipment.id, containers: [container]})

  $scope.deleteContainer = (shipment,container) ->
    doAction = window.confirm("Are you sure you want to delete this container?")
    if doAction
      container._destroy = 'true'
      $scope.saveShipment({id: shipment.id, containers: [container]})

  $scope.showProcessManifest = ->
    $state.go('process_manifest.main',{shipmentId: $scope.shp.id})

  $scope.showAddOrder = ->
    $state.go('add_order',{shipmentId: $scope.shp.id})

  $scope.showBookOrder = ->
    $state.go('book_order',{shipmentId: $scope.shp.id})

  $scope.sendISF = (shipment) ->
    actuallySend = ->
      $scope.loadingFlag = 'loading'
      $scope.eh.clear()
      shipmentSvc.sendISF(shipment).finally -> $scope.loadingFlag = null

    if $scope.shp.shp_isf_sent_at
      if window.confirm("An ISF has already been sent. Are you sure you want to send it again?")
        actuallySend()
    else
      actuallySend()

  $scope.saveShipment = (shipment) ->
    $scope.loadingFlag = 'loading'
    $scope.eh.clear()
    $scope.notificationMessage = "Saving shipment."
    shipmentSvc.saveShipment(shipment).finally ->
      $scope.loadShipment(shipment.id).finally ->
        $scope.loadingFlag = null

  if $state.params.shipmentId
    $scope.loadShipment $state.params.shipmentId

]
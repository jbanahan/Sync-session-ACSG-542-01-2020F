angular.module('ShipmentApp').controller 'ShipmentShowCtrl', ['$scope','shipmentSvc','$state','chainErrorHandler', '$window', 'chainDomainerSvc', ($scope,shipmentSvc,$state,chainErrorHandler, $window, chainDomainerSvc) ->
  loadCarriers = (importerId) ->
    $scope.carriers = undefined
    shipmentSvc.getCarriers(importerId).success((data) ->
      $scope.carriers = data.carriers
    )

  loadImporters = ->
    $scope.importers = undefined
    shipmentSvc.getImporters().success((data) ->
      $scope.importers = data.importers
    )

  bookingAction = (shipment, redoCheckField, actionMethod, namePastTense) ->
    doRequest = true
    if redoCheckField.length > 0
      doRequest = window.confirm("A booking has already been "+namePastTense+". Are you sure you want to do this again?")
    if doRequest
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      actionMethod(shipment).then (resp) ->
        $scope.loadShipment(sId).then ->
          window.alert('Booking '+namePastTense+'.')
  
  $scope.loadSearchModal = (field, number) ->
    $('#search-modal').modal('show')
    shipmentSvc.getQuickSearch(field, number).then (data) ->
      $window.OCQuickSearch.writeModuleResponse data, null, null, true, true    

  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    $scope.notificationMessage = null
  $scope.shp = null
  $scope.remove_shp_ord = null

  $scope.loadShipment = (id) ->
    $scope.loadingFlag = 'loading'
    shipmentSvc.getShipment(id, $scope.shipmentLinesNeeded, $scope.bookingLinesNeeded).then (resp) ->
      $scope.shp = resp.data.shipment
      if $scope.shp.shp_in_warehouse_time
        $scope.shp._warehouse_time_moment = moment($scope.shp.shp_in_warehouse_time)
        $scope.shp._shp_warehouse_time_date = $scope.shp._warehouse_time_moment.format("YYYY-MM-DD")
        $scope.shp._shp_warehouse_time_hour = $scope.shp._warehouse_time_moment.format("HH:mm")
      else
        $scope.shp._warehouse_time_moment = moment()
        $scope.shp._shp_warehouse_time_date = ''
        $scope.shp._shp_warehouse_time_hour = ''
      addConditionalFields $scope.shp
      $scope.loadingFlag = null

  $scope.uniqueOrderOptions = (lines) ->
    orders = []
    for line in lines
      for order_line in line.order_lines
        item = {order_id: order_line.order_id, order_number: $scope.shipmentLineOrderNumber(order_line)}
        
        # Ensure that there are only unique order lines
        found = false
        for ol in orders
          if ol.order_id == item.order_id
            found = true
        
        unless found
          orders.push item 
    orders

  addConditionalFields = (shp) ->
    fields = {}
    if shp.screen_settings.percentage_field == "by product"
      fields.orderNumber = {label: "Order Number", fieldName: "bkln_order_number"}
      fields.orderQuantity = {label: "Product Summed<br>Order Quantity", fieldName: "bkln_summed_order_line_quantity"}
      fields.percentageBooked = {label: "Percentage Booked<br>By Product", fieldName: "bkln_quantity_diff_by_product"}
    else
      fields.orderNumber = {label: "Order Number - Line", fieldName: "bkln_order_and_line_number"}
      fields.orderQuantity = {label: "Order Quantity", fieldName: "bkln_order_line_quantity"}
      fields.percentageBooked = {label: "Percentage Booked", fieldName: "bkln_quantity_diff"}
    shp.conditionalFields = fields

  $scope.shipmentLinesSelected = (shp) ->
    # Only load shipment lines on tab selection the first time
    # we load the screen, every other time after that they'll be reloaded
    # shipment load calls, line reloads, etc
    unless $scope.shipmentLinesNeeded?
      $scope.loadShipmentLines(shp)

  $scope.loadShipmentLines = (shp) ->
    $scope.shipmentLinesNeeded = true
    shipmentSvc.injectShipmentLines(shp)

  $scope.bookingLinesSelected = (shp) ->
    # Only load booking lines on tab selection the first time
    # we load the screen, every other time after that they'll be reloaded
    # shipment load calls, line reloads, etc
    unless $scope.bookingLinesNeeded?
      $scope.loadBookingLines(shp)

  $scope.loadBookingLines = (shp) ->
    $scope.bookingLinesNeeded = true
    shipmentSvc.injectBookingLines(shp)

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
        $scope.loadShipment(sId).then ->
          window.alert('Booking opened for revision.')

  $scope.requestCancel = (shipment) ->
    if window.confirm("Are you sure you want to request to cancel this shipment?")
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      shipmentSvc.requestCancel(shipment).then (resp) ->
        $scope.loadShipment(sId).then ->
          window.alert('Request sent.')

  $scope.cancelShipment = (shipment) ->
    if window.confirm("Are you sure you want to cancel this shipment?")
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      shipmentSvc.cancelShipment(shipment).then (resp) ->
        $scope.loadShipment(sId).then ->
          window.alert('Shipment canceled.')

  $scope.uncancelShipment = (shipment) ->
    if window.confirm("Are you sure you want to undo canceling this shipment?")
      $scope.loadingFlag = 'loading'
      sId = shipment.id
      shipmentSvc.uncancelShipment(shipment).then (resp) ->
        $scope.loadShipment(sId).then ->
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

  portSelectedCallback = (port) ->
    (item) ->
      if item
        $scope.header[port + '_id'] = item.originalObject.id
        # Remove this attribute so we don't have port names in the save requests sent, only ids
        delete $scope.header[port + '_name']

  $scope.prepShipmentHeaderEdit = (shipment) ->
    $scope.header = angular.copy(shipment)
    $scope.header.destPortSelected = portSelectedCallback('shp_dest_port')
    $scope.header.finalDestPortSelected = portSelectedCallback('shp_final_dest_port')
    $scope.header.firstPortReceiptSelected = portSelectedCallback('shp_first_port_receipt')
    $scope.header.ladingPortSelected = portSelectedCallback('shp_lading_port')
    $scope.header.lastForeignPortSelected = portSelectedCallback('shp_last_foreign_port')
    $scope.header.unladingPortSelected = portSelectedCallback('shp_unlading_port')
    $scope.header.inlandDestPortSelected = portSelectedCallback('shp_inland_dest_port')

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

  ###*
  # shpln_container_id and shpln_container_number must be purged from the request to allow a different container
  # to be selected.  If that's not done, the selected container value (shpln_container_uid) is ignored.
  ###
  saveShipmentLine = (shipment,line) ->
    delete line.shpln_container_id
    delete line.shpln_container_number
    saveLine(shipment.id, line, 'lines')

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

  $scope.removePO = (shipment,order) ->
    if window.confirm("Are you sure you want to delete PO #{order.order_number}?")
      for line in shipment.lines
        for oln in line.order_lines
          if oln.order_id == order.order_id
            line._destroy = 'true'
      $('#mod_remove_po').modal('hide')
      $scope.saveShipment({id: shipment.id, lines: shipment.lines})

  $scope.deleteAllBookingLines = (shipment) ->
    if window.confirm("Are you sure you want to delete all booking lines from this shipment?")
      for line in shipment.booking_lines
        line._destroy = 'true'

      $scope.saveShipment({id: shipment.id, booking_lines: shipment.booking_lines})

  $scope.deleteAllLines = (shipment) ->
    if window.confirm("Are you sure you want to delete all lines from this shipment?")
      for line in shipment.lines
        line._destroy = 'true'

      $scope.saveShipment({id: shipment.id, lines: shipment.lines})

  $scope.prepBookingEditObject = copyObjectToScopeAs 'booking'

  $scope.prepPartiesModal = copyObjectToScopeAs 'partyLine'

  $scope.prepPartiesEditObject = (shipment) ->
    loadCarriers(shipment.shp_imp_id) unless $scope.carriers
    $scope.partiesEditObj =
      id: shipment.id
      shp_car_syscode: shipment.shp_car_syscode

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

  $scope.shipmentLineOrderNumber = (shipmentLine) ->
    ord = shipmentLine.ord_cust_ord_no
    ord = shipmentLine.ord_ord_num unless ord
    ord

  $scope.showHistory = (shipment) ->
    $window.location.href = '/shipments/'+shipment.id+'/history'

  update_time = (newVal) ->
    timeArray = newVal.split(':')
    if timeArray.length == 2
      $scope.tracking._warehouse_time_moment.hour(timeArray[0])
      $scope.tracking._warehouse_time_moment.minute(timeArray[1])
      format_in_warehouse_time()

  format_in_warehouse_time = ->
    $scope.tracking.shp_in_warehouse_time = $scope.tracking._warehouse_time_moment.format("YYYY-MM-DDTHH:mm")

  update_date = (newVal) ->
    dateArray = newVal.split('-')
    if dateArray.length == 3

      # Because moment 0 indexes month, let's strip off the 0 (If present) and subtract 1.
      month = parseInt(dateArray[1], 10) - 1

      $scope.tracking._warehouse_time_moment.year(dateArray[0])
      $scope.tracking._warehouse_time_moment.month(month)
      $scope.tracking._warehouse_time_moment.date(dateArray[2])
      format_in_warehouse_time()

  $scope.label = (fieldName) ->
    if $scope.dictionary
      fld = $scope.dictionary.field(fieldName)
      if fld
        fld.label
      else
        ''
    else
      ''

  $scope.$watch 'tracking._shp_warehouse_time_hour', (newVal, oldVal) ->
    if $scope.tracking && /\d{2}:\d{2}/.exec(newVal)
      update_time(newVal)


  $scope.$watch 'tracking._shp_warehouse_time_date', (newVal, oldVal) ->
    if $scope.tracking && /\d{4}-\d{2}-\d{2}/.exec(newVal)
      update_date(newVal)

  if $state.params.shipmentId
    if $scope.dictionary
      $scope.loadShipment $state.params.shipmentId
    else
      chainDomainerSvc.withDictionary().then (dict) ->
        $scope.dictionary = dict
        $scope.loadShipment $state.params.shipmentId

]

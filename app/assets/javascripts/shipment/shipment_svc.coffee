angular.module('ShipmentApp').factory 'shipmentSvc', ['$http','$q','commentSvc',($http,$q,commentSvc) ->
  prepForSave = (shipment) ->
    shipment.lines = markZeroQuantityLinesForDestruction shipment.lines
    shipment.booking_lines = markZeroQuantityLinesForDestruction shipment.booking_lines
    setPortNames(shipment)
    shipment

  markZeroQuantityLinesForDestruction = (lines=[]) ->
    updatedLines = []
    for ln in lines
      qty = parseFloat(ln.shpln_shipped_qty || ln.bkln_quantity)
      if ln.id
        if !qty || qty==0
          ln._destroy = true
        updatedLines.push ln
      else
        updatedLines.push ln if qty && qty>0
    updatedLines

  setPortNames = (shipment) ->
    names = ['dest_port', 'first_port_receipt', 'lading_port', 'last_foreign_port', 'unlading_port']
    for name in names
      setPortName shipment, name

  setPortName = (shipment, portName) ->
    if shipment[portName] && shipment[portName].title
      shipment["shp_#{portName}_name"] = shipment[portName].title
      shipment["shp_#{portName}_id"] = undefined

  currentShipment = null
  getShipmentSuccessHandler = (resp) ->
    currentShipment = angular.extend({}, currentShipment, resp.data.shipment) # merge changes instead of replacing, or else you lose extras: summary, lines, etc.
    if currentShipment.shp_dest_port_id > 0
      currentShipment.dest_port = {
        id: currentShipment.shp_dest_port_id
        name: currentShipment.shp_dest_port_name
      }
    commentSvc.injectComments(currentShipment,'Shipment')
    resp

  shipmentPost = (id, endpoint, options={id:id}) ->
    $http.post('/api/v1/shipments/'+id+'/'+endpoint, options)

  return {
    getShipment: (shipmentId,forceReload) ->
      if !forceReload && currentShipment && parseInt(currentShipment.id) == parseInt(shipmentId)
        $q.when {data: {shipment: currentShipment}}
      else
        $http.get('/api/v1/shipments/'+shipmentId+'.json?summary=true&no_lines=true&include=order_lines,attachments').then(getShipmentSuccessHandler)

    injectShipmentLines: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'.json?shipment_lines=true&include=order_lines').then (resp) ->
        shipment.lines = resp.data.shipment.lines

    injectBookingLines: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'.json?booking_lines=true&include=order_lines').then (resp) ->
        shipment.booking_lines = resp.data.shipment.booking_lines

    saveShipment: (shipment) ->
      currentShipment = null
      method = "post"
      suffix = ""
      s = prepForSave shipment

      if shipment.id && shipment.id > 0
        method = "put"
        suffix = "/#{s.id}.json"

      $http[method]("/api/v1/shipments#{suffix}",{shipment: s}).then(getShipmentSuccessHandler)

    saveBookingLines: (lines, shipmentId) ->
      $http.put("/api/v1/shipments/#{shipmentId}.json", {shipment:{id:shipmentId, booking_lines:lines}, summary:true}).then getShipmentSuccessHandler

    getParties: ->
      $http.get('/api/v1/companies?roles=importer,carrier&isf=true')

    getAvailableOrders: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'/available_orders.json')

    getBookedOrders: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'/booked_orders.json')

    getAvailableLines: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'/available_lines.json')

    getOrder: (id) ->
      $http.get('/api/v1/orders/'+id)

    processTradecardPackManifest: (shp, attachment, manufacturerAddressId) ->
      shipmentPost(shp.id, 'process_tradecard_pack_manifest', {attachment_id: attachment.id, manufacturer_address_id:manufacturerAddressId}).then(getShipmentSuccessHandler)

    processBookingWorksheet: (shp, attachment) ->
      shipmentPost(shp.id, 'process_booking_worksheet', {attachment_id: attachment.id}).then(getShipmentSuccessHandler)

    requestBooking: (shp) ->
      shipmentPost(shp.id, 'request_booking.json')

    approveBooking: (shp) ->
      shipmentPost(shp.id, 'approve_booking.json')

    confirmBooking: (shp) ->
      shipmentPost(shp.id, 'confirm_booking.json')

    reviseBooking: (shp) ->
      shipmentPost(shp.id, 'revise_booking.json')

    requestCancel: (shp) ->
      shipmentPost(shp.id, 'request_cancel.json')

    cancelShipment: (shp) ->
      shipmentPost(shp.id, 'cancel.json')

    uncancelShipment: (shp) ->
      shipmentPost(shp.id,'uncancel.json')

    sendISF: (shp) ->
      shipmentPost(shp.id,'send_isf.json')
  }
]

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
    names = ['dest_port', 'final_dest_port', 'first_port_receipt', 'lading_port', 'last_foreign_port', 'unlading_port']
    for name in names
      setPortName shipment, name

  setPortName = (shipment, portName) ->
    if shipment[portName] && shipment[portName].title
      shipment["shp_#{portName}_name"] = shipment[portName].title
      shipment["shp_#{portName}_id"] = undefined

  currentShipment = null

  shipmentPost = (id, endpoint, options={id:id}) ->
    $http.post("/api/v1/shipments/#{id}/#{endpoint}", options)

  shipmentGet = (id, endpoint) ->
    $http.get("/api/v1/shipments/#{id}/#{endpoint}")

  return {
    getShipment: (shipmentId, shipmentLines, bookingLines) ->
      requestParams = "summary=true&include=order_lines,attachments,comments,containers"
      requestParams += "&shipment_lines=true" if shipmentLines
      requestParams += "&booking_lines=true" if bookingLines

      $http.get('/api/v1/shipments/'+shipmentId+'.json?' + requestParams)

    injectShipmentLines: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'/shipment_lines.json?include=order_lines').then (resp) ->
        shipment.lines = resp.data.shipment.lines

    injectBookingLines: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'/booking_lines.json').then (resp) ->
        shipment.booking_lines = resp.data.shipment.booking_lines

    saveShipment: (shipment) ->
      currentShipment = null
      method = "post"
      suffix = ""
      s = prepForSave shipment

      if shipment.id && shipment.id > 0
        method = "put"
        suffix = "/#{s.id}.json"

      $http[method]("/api/v1/shipments#{suffix}",{shipment: s})

    saveBookingLines: (lines, shipmentId) ->
      $http.put("/api/v1/shipments/#{shipmentId}.json", {shipment:{id:shipmentId, booking_lines:lines}, summary:true})

    getImporters: ->
      $http.get('/api/v1/companies?roles=importer')

    getCarriers: (importerId) ->
      $http.get('/api/v1/companies?roles=carrier&linked_with=' + importerId)

    getAvailableOrders: (shipment) ->
      shipmentGet(shipment.id, 'available_orders.json')

    getBookedOrders: (shipment) ->
      shipmentGet(shipment.id, 'booked_orders.json')

    getAvailableLines: (shipment) ->
      shipmentGet(shipment.id, 'available_lines.json')

    getOrder: (id) ->
      $http.get('/api/v1/orders/'+id)

    getOrderShipmentRefs: (orderId)->
      searchArgs = {sid1:'shp_shipped_order_ids', sop1:'co', sv1:orderId}
      $http.get('/api/v1/shipments.json',{params: searchArgs}).then (resp) ->
        r = []
        for v in resp.data.results
          r.push(v)
        return r.map (s) -> s.shp_ref

    processTradecardPackManifest: (shp, attachment, manufacturerAddressId, enableWarnings) ->
      shipmentPost(shp.id, 'process_tradecard_pack_manifest', {attachment_id: attachment.id, manufacturer_address_id:manufacturerAddressId, enable_warnings:enableWarnings})

    processBookingWorksheet: (shp, attachment, placeHolder, enableWarnings) ->
      shipmentPost(shp.id, 'process_booking_worksheet', {attachment_id: attachment.id, enable_warnings:enableWarnings})

    processManifestWorksheet: (shp, attachment, placeHolder, enableWarnings) ->
      shipmentPost(shp.id, 'process_manifest_worksheet', {attachment_id: attachment.id, enable_warnings:enableWarnings})

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

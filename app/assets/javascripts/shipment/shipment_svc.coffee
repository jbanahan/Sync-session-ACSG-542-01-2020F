angular.module('ShipmentApp').factory 'shipmentSvc', ['$http','$q','commentSvc',($http,$q,commentSvc) ->
  prepForSave = (shipment) ->
    updatedLines = []
    if shipment.lines
      for ln in shipment.lines
        qty = parseFloat(ln.shpln_shipped_qty)
        if ln.id
          if !qty || qty==0
            ln._destroy = true
          updatedLines.push ln
        else
          updatedLines.push ln if qty && qty>0
      shipment.lines = updatedLines
    setPortNames(shipment)
    shipment

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
    currentShipment = resp.data.shipment
    if currentShipment.shp_dest_port_id > 0
      currentShipment.dest_port = {
        id: currentShipment.shp_dest_port_id
        name: currentShipment.shp_dest_port_name
      }
    commentSvc.injectComments(currentShipment,'Shipment')
    resp

  shipmentPost = (id, endpoint) ->
    $http.post('/api/v1/shipments/'+id+'/'+endpoint, {id: id})

  return {
    getShipment: (shipmentId,forceReload) ->
      if !forceReload && currentShipment && parseInt(currentShipment.id) == parseInt(shipmentId)
        $q.when {data: {shipment: currentShipment}}
      else
        $http.get('/api/v1/shipments/'+shipmentId+'.json?summary=true&no_lines=true&include=order_lines,attachments').then(getShipmentSuccessHandler)

    injectLines: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'.json?shipment_lines=true&include=order_lines').then (resp) ->
        shipment.lines = resp.data.shipment.lines

    saveShipment: (shipment) ->
      currentShipment = null
      method = "post"
      suffix = ""
      s = prepForSave shipment

      if shipment.id && shipment.id > 0
        method = "put"
        suffix = "/#{s.id}.json"

      $http[method]("/api/v1/shipments#{suffix}",{shipment: s, no_lines: 'true'}).then(getShipmentSuccessHandler)

    getParties: ->
      $http.get('/api/v1/companies?roles=importer,carrier')

    getAvailableOrders: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'/available_orders.json')

    getOrder: (id) ->
      $http.get('/api/v1/orders/'+id)

    processTradecardPackManifest: (shp, attachment) ->
      $http.post('/api/v1/shipments/'+shp.id+'/process_tradecard_pack_manifest', {attachment_id: attachment.id, no_lines: 'true'}).then(getShipmentSuccessHandler)

    requestBooking: (shp) ->
      shipmentPost(shp.id, 'request_booking.json')

    approveBooking: (shp) ->
      shipmentPost(shp.id, 'approve_booking.json')

    confirmBooking: (shp) ->
      shipmentPost(shp.id, 'confirm_booking.json')

    reviseBooking: (shp) ->
      shipmentPost(shp.id, 'revise_booking.json')

    cancelShipment: (shp) ->
      shipmentPost(shp.id, 'cancel.json')

    uncancelShipment: (shp) ->
      shipmentPost(shp.id,'uncancel.json')
  }
]

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
    if shipment.dest_port && shipment.dest_port.title
      shipment.shp_dest_port_name = shipment.dest_port.title
      shipment.shp_dest_port_id = undefined
    shipment

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

  return {
    getShipment: (shipmentId,forceReload) ->
      if !forceReload && currentShipment && parseInt(currentShipment.id) == parseInt(shipmentId)
        deferred = $q.defer()
        deferred.resolve {data: {shipment: currentShipment}}
        return deferred.promise
      else
        return $http.get('/api/v1/shipments/'+shipmentId+'.json?summary=true&no_lines=true&include=order_lines,attachments').then(getShipmentSuccessHandler)

    injectLines: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'.json?shipment_lines=true&include=order_lines').then (resp) ->
        shipment.lines = resp.data.shipment.lines

    saveShipment: (shipment) ->
      currentShipment = null
      s = prepForSave shipment
      if shipment.id && shipment.id > 0
        $http.put('/api/v1/shipments/'+s.id+'.json', {shipment: s, no_lines: 'true'}).then(getShipmentSuccessHandler)
      else
        $http.post('/api/v1/shipments',{shipment: s, no_lines: 'true'}).then(getShipmentSuccessHandler)

    getParties: ->
      $http.get('/api/v1/companies?roles=importer,carrier')

    getAvailableOrders: (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'/available_orders.json')

    getOrder: (id) ->
      $http.get('/api/v1/orders/'+id)

    processTradecardPackManifest: (shp, attachment) ->
      $http.post('/api/v1/shipments/'+shp.id+'/process_tradecard_pack_manifest', {attachment_id: attachment.id, no_lines: 'true'}).then(getShipmentSuccessHandler)

    requestBooking: (shp) ->
      $http.post('/api/v1/shipments/'+shp.id+'/request_booking.json',{id: shp.id}) #need some json content for API controller

    approveBooking: (shp) ->
      $http.post('/api/v1/shipments/'+shp.id+'/approve_booking.json',{id: shp.id}) #need some json content for API controller

    confirmBooking: (shp) ->
      $http.post('/api/v1/shipments/'+shp.id+'/confirm_booking.json',{id: shp.id}) #need some json content for API controller

    reviseBooking: (shp) ->
      $http.post('/api/v1/shipments/'+shp.id+'/revise_booking.json',{id: shp.id}) #need some json content for API controller

    cancelShipment: (shp) ->
      $http.post('/api/v1/shipments/'+shp.id+'/cancel.json',{id: shp.id}) #need some json content for API controller

    uncancelShipment: (shp) ->
      $http.post('/api/v1/shipments/'+shp.id+'/uncancel.json',{id: shp.id}) #need some json content for API controller
  }
]

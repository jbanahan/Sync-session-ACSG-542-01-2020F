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
    if shipment.dest_port.title
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
        deferred.resolve {data:{shipment:currentShipment}}
        return deferred.promise
      else
        return $http.get('/api/v1/shipments/'+shipmentId+'.json?include=order_lines,attachments').then(getShipmentSuccessHandler)
    saveShipment: (shipment) ->
      currentShipment = null
      s = prepForSave shipment
      if shipment.id && shipment.id > 0
        $http.put('/api/v1/shipments/'+s.id+'.json',{shipment: s, include:'order_lines,attachments'}).then(getShipmentSuccessHandler)
      else
        $http.post('/api/v1/shipments',{shipment: s, include:'order_lines,attachments'}).then(getShipmentSuccessHandler)
    getParties: ->
      $http.get('/api/v1/companies?roles=importer,carrier')
    getAvailableOrders : (shipment) ->
      $http.get('/api/v1/shipments/'+shipment.id+'/available_orders.json')
    getOrder: (id) ->
      $http.get('/api/v1/orders/'+id)
    processTradecardPackManifest: (shp, attachment) ->
      $http.post('/api/v1/shipments/'+shp.id+'/process_tradecard_pack_manifest',{attachment_id:attachment.id, include:'order_lines,attachments'}).then(getShipmentSuccessHandler)
  }
]
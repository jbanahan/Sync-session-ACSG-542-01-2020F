angular.module('ShipmentApp').factory 'shipmentSvc', ['$http','$q',($http,$q) ->
  maxVal = (ary,attr,min) ->
    r = min
    for x in ary
      pX = (if x[attr] then parseInt(x[attr]) else min)
      r = pX if pX > r
    r
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
    shipment

  currentShipment = null
  getShipmentSuccessHandler = (resp) ->
    currentShipment = resp.data.shipment
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
    getAvailableOrders : (page) ->
      $http.get('/api/v1/orders?fields=ord_ord_num,ord_ven_name&page='+page)
    getOrder: (id) ->
      $http.get('/api/v1/orders/'+id)
    #create shipment lines for all lines on the given order
    addOrderToShipment: (shp, ord, container_to_pack) ->
      shp.lines = [] if shp.lines==undefined
      nextLineNumber = maxVal(shp.lines,'shpln_line_number',0) + 1
      return shp unless ord.lines
      for oln in ord.lines
        sl = {
          shpln_line_number:nextLineNumber,
          shpln_puid:oln.ordln_puid,
          shpln_pname:oln.ordln_pname,
          linked_order_line_id:oln.id,
          order_lines:[{ord_cust_ord_no:ord.ord_cust_ord_no,ordln_line_number:oln.ordln_line_number}]
        }
        sl.shpln_container_uid = container_to_pack.id if container_to_pack
        shp.lines.push sl
        nextLineNumber = nextLineNumber + 1
      shp
  }
]
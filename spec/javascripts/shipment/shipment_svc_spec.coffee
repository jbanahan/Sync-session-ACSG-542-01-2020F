describe 'ShipmentApp', ->

  beforeEach module('ShipmentApp')

  describe 'shipmentSvc', ->
    http = svc = commentSvc = null

    beforeEach inject((shipmentSvc,_commentSvc_,$httpBackend) ->
      svc = shipmentSvc
      http = $httpBackend
      commentSvc = _commentSvc_
      spyOn(commentSvc,'injectComments')
    )

    afterEach ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'getShipment', ->
      it 'should get shipment from server', ->
        resp = {shipment: {id: 1}}
        http.expectGET('/api/v1/shipments/1.json?summary=true&no_lines=true&include=order_lines,attachments').respond resp
        shp = null
        svc.getShipment(1).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp
        expect(commentSvc.injectComments).toHaveBeenCalledWith(resp.shipment,'Shipment')

    describe 'injectLines', ->
      it 'should add lines to existing object', ->
        expected_line_array = [{id: 10},{id: 11}]
        resp = {shipment: {id: 1, lines: expected_line_array}}
        s = {id: 1}
        http.expectGET('/api/v1/shipments/1.json?include=order_lines').respond resp
        svc.injectLines(s)
        http.flush()
        expect(s.lines).toEqual expected_line_array

    describe 'saveShipment', ->
      it "should remove zero quantity lines that don't already have an ID", ->
        start = {ship_ref: 'REF',lines: [{shpln_shipped_qty: '0'}]}
        expected = {ship_ref: 'REF', lines: []}
        http.expectPOST('/api/v1/shipments',{shipment: expected,include: 'order_lines,attachments'}).respond {shipment: expected}
        svc.saveShipment(start)
        http.flush()

      it "should flag zero quantity lines with an ID for destroy", ->
        start = {ship_ref: 'REF', lines: [{id: 7, shpln_shipped_qty: '0'}]}
        expected = {ship_ref: 'REF', lines: [{id: 7, shpln_shipped_qty: '0', _destroy: true}]}
        http.expectPOST('/api/v1/shipments', {shipment: expected, include: 'order_lines,attachments'}).respond {shipment: expected}
        svc.saveShipment(start)
        http.flush()

      it "should keep lines with a quantity", ->
        start = {ship_ref: 'REF', lines: [{id: 7, shpln_shipped_qty: '5'}, {shpln_shipped_qty: '6'}]}
        expected = {ship_ref: 'REF', lines: [{id: 7, shpln_shipped_qty: '5'}, {shpln_shipped_qty: '6'}]}
        http.expectPOST('/api/v1/shipments', {shipment: expected, include: 'order_lines,attachments'}).respond {shipment: expected}
        svc.saveShipment(start)
        http.flush()

      it 'should send post for create', ->
        base = {shp_ref: 'REF'}
        resp = {shipment: {id: 1}}
        http.expectPOST('/api/v1/shipments', {shipment: base, include: 'order_lines,attachments'}).respond resp
        shp = null
        svc.saveShipment(base).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

      it 'should send put for update', ->
        base = {shp_ref: 'REF', id: 1}
        resp = {shipment: {id: 1}}
        http.expectPUT('/api/v1/shipments/1.json',{shipment: base, include: 'order_lines,attachments'}).respond resp
        shp = null
        svc.saveShipment(base).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

    describe 'getParties', ->
      it 'should query companies api', ->
        resp = {'importers': [{id: 1}]}
        http.expectGET('/api/v1/companies?roles=importer,carrier').respond resp
        d = null
        svc.getParties().success (data) ->
          d = data
        http.flush()
        expect(d).toEqual resp

    describe 'getAvailableOrders', ->
      it 'should query orders api', ->
        resp = {'available_orders': [{id: 1}]}
        shp = {id: 10}
        http.expectGET('/api/v1/shipments/10/available_orders.json').respond resp
        d = null
        svc.getAvailableOrders(shp).success (data) ->
          d = data
        http.flush()
        expect(d).toEqual resp

    describe 'getOrder', ->
      it 'should query orders api', ->
        resp = {order: {id: 1, ord_ord_num: 'x'}}
        http.expectGET('/api/v1/orders/1').respond resp
        d = null
        svc.getOrder(1).success (data) ->
          d = data
        http.flush()
        expect(d).toEqual resp

    describe 'processTradecardPackManifest', ->
      it 'should submit', ->
        resp = {shipment: {id: 1}}
        http.expectPOST('/api/v1/shipments/1/process_tradecard_pack_manifest',{attachment_id: 2,include: 'order_lines,attachments'}).respond resp
        shp = null
        svc.processTradecardPackManifest({id: 1},{id: 2}).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

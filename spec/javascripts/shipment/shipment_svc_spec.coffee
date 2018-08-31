
describe 'ShipmentService', ->

  beforeEach module('ShipmentApp')

  describe 'shipmentSvc', ->
    http = svc = null

    beforeEach inject((shipmentSvc,_commentSvc_,$httpBackend) ->
      svc = shipmentSvc
      http = $httpBackend
    )

    afterEach ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'getShipment', ->
      it 'should get shipment from server', ->
        resp = {shipment: {id: 1}}
        http.expectGET('/api/v1/shipments/1.json?summary=true&include=order_lines,attachments,comments,containers').respond resp
        shp = null
        svc.getShipment(1).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

      it 'should get shipment from server, including shipmentLines', ->
        resp = {shipment: {id: 1}}
        http.expectGET('/api/v1/shipments/1.json?summary=true&include=order_lines,attachments,comments,containers&shipment_lines=true').respond resp
        shp = null
        svc.getShipment(1, true).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

      it 'should get shipment from server, including bookingLines', ->
        resp = {shipment: {id: 1}}
        http.expectGET('/api/v1/shipments/1.json?summary=true&include=order_lines,attachments,comments,containers&booking_lines=true').respond resp
        shp = null
        svc.getShipment(1, false, true).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

      it 'should get shipment from server, including shipment & bookingLines', ->
        resp = {shipment: {id: 1}}
        http.expectGET('/api/v1/shipments/1.json?summary=true&include=order_lines,attachments,comments,containers&shipment_lines=true&booking_lines=true').respond resp
        shp = null
        svc.getShipment(1, true, true).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

    describe 'injectShipmentLines', ->
      it 'should add lines to existing object', ->
        expected_line_array = [{id: 10},{id: 11}]
        resp = {shipment: {id: 1, lines: expected_line_array}}
        s = {id: 1}
        http.expectGET('/api/v1/shipments/1/shipment_lines.json?include=order_lines').respond resp
        svc.injectShipmentLines(s)
        http.flush()
        expect(s.lines).toEqual expected_line_array

    describe 'injectBookingLines', ->
      it 'should add lines to existing object', ->
        expected_line_array = [{id: 10},{id: 11}]
        resp = {shipment: {id: 1, booking_lines: expected_line_array}}
        s = {id: 1}
        http.expectGET('/api/v1/shipments/1/booking_lines.json').respond resp
        svc.injectBookingLines(s)
        http.flush()
        expect(s.booking_lines).toEqual expected_line_array

    describe 'saveShipment', ->
      it "should remove zero quantity lines that don't already have an ID", ->
        start = {ship_ref: 'REF',lines: [{shpln_shipped_qty: '0'}]}
        expected = {ship_ref: 'REF', lines: [], booking_lines: []}
        http.expectPOST('/api/v1/shipments',{shipment: expected}).respond {shipment: expected}
        svc.saveShipment(start)
        expect(http.flush).not.toThrow()

      it "should flag zero quantity lines with an ID for destroy", ->
        start = {ship_ref: 'REF', lines: [{id: 7, shpln_shipped_qty: '0'}]}
        expected = {ship_ref: 'REF', lines: [{id: 7, shpln_shipped_qty: '0', _destroy: true}], booking_lines:[]}
        http.expectPOST('/api/v1/shipments', {shipment: expected}).respond {shipment: expected}
        svc.saveShipment(start)
        expect(http.flush).not.toThrow()

      it "should keep lines with a quantity", ->
        start = {ship_ref: 'REF', lines: [{id: 7, shpln_shipped_qty: '5'}, {shpln_shipped_qty: '6'}]}
        expected = {ship_ref: 'REF', lines: [{id: 7, shpln_shipped_qty: '5'}, {shpln_shipped_qty: '6'}], booking_lines:[]}
        http.expectPOST('/api/v1/shipments', {shipment: expected}).respond {shipment: expected}
        svc.saveShipment(start)
        expect(http.flush).not.toThrow()

      it 'should send post for create', ->
        base = {shp_ref: 'REF'}
        resp = {shipment: {id: 1}}
        http.expectPOST('/api/v1/shipments', {shipment: base}).respond resp
        shp = null
        svc.saveShipment(base).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

      it 'should send put for update', ->
        base = {shp_ref: 'REF', id: 1}
        resp = {shipment: {id: 1}}
        http.expectPUT('/api/v1/shipments/1.json',{shipment: base}).respond resp
        shp = null
        svc.saveShipment(base).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

    describe 'requestBooking', ->
      it 'should request booking', ->
        resp = {ok: 'ok'}
        shp = {id: 10}
        http.expectPOST('/api/v1/shipments/10/request_booking.json').respond resp
        svc.requestBooking(shp)
        expect(http.flush).not.toThrow()

    describe 'approveBooking', ->
      it 'should approve booking', ->
        resp = {ok: 'ok'}
        shp = {id: 10}
        http.expectPOST('/api/v1/shipments/10/approve_booking.json').respond resp
        svc.approveBooking(shp)
        expect(http.flush).not.toThrow()

    describe 'confirmBooking', ->
      it 'should confirm booking', ->
        resp = {ok: 'ok'}
        shp = {id: 10}
        http.expectPOST('/api/v1/shipments/10/confirm_booking.json').respond resp
        svc.confirmBooking(shp)
        expect(http.flush).not.toThrow()

    describe 'reviseBooking', ->
      it 'should revise booking', ->
        resp = {ok: 'ok'}
        shp = {id: 10}
        http.expectPOST('/api/v1/shipments/10/revise_booking.json').respond resp
        svc.reviseBooking(shp)
        expect(http.flush).not.toThrow()

    describe 'cancelShipment', ->
      it 'should cancel', ->
        resp = {ok: 'ok'}
        shp = {id: 10}
        http.expectPOST('/api/v1/shipments/10/cancel.json').respond resp
        svc.cancelShipment(shp)
        expect(http.flush).not.toThrow()

    describe 'uncancelShipment', ->
      it 'should uncancel', ->
        resp = {ok: 'ok'}
        shp = {id: 10}
        http.expectPOST('/api/v1/shipments/10/uncancel.json').respond resp
        svc.uncancelShipment(shp)
        expect(http.flush).not.toThrow()

    describe 'getImporters', ->
      it 'should query companies api', ->
        resp = {'importers': [{id: 1}]}
        http.expectGET('/api/v1/companies?roles=importer').respond resp
        d = null
        svc.getImporters().success (data) ->
          d = data
        http.flush()
        expect(d).toEqual resp

    describe 'getCarriers', ->
      it 'should query companies api', ->
        resp = {'carriers': [{id: 1}]}
        http.expectGET('/api/v1/companies?roles=carrier&linked_with=1').respond resp
        d = null
        svc.getCarriers(1).success (data) ->
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
        http.expectPOST('/api/v1/shipments/1/process_tradecard_pack_manifest',{attachment_id: 2, manufacturer_address_id:3, enable_warnings:true}).respond resp
        shp = null
        svc.processTradecardPackManifest({id: 1},{id: 2}, 3, true).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

    describe 'processManifestWorksheet', ->
      it 'should submit', ->
        resp = {shipment: {id: 1}}
        http.expectPOST('/api/v1/shipments/1/process_manifest_worksheet',{attachment_id: 2, enable_warnings:true}).respond resp
        shp = null
        svc.processManifestWorksheet({id: 1},{id: 2}, null, true).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

    describe 'processBookingWorksheet', ->
      it 'should submit', ->
        resp = {shipment: {id: 1}}
        http.expectPOST('/api/v1/shipments/1/process_booking_worksheet',{attachment_id: 2, enable_warnings:true}).respond resp
        shp = null
        svc.processBookingWorksheet({id: 1},{id: 2}, null, true).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

    describe 'getOrderShipmentRefs', ->
      it 'returns a list of shipment references associated with an order ID', ->
        resp = {results: [{shp_ref: 'REF1'},{shp_ref: 'REF2'},{shp_ref: 'REF3'}]}
        searchArgs = {sid1:'shp_shipped_order_ids', sop1:'co', sv1:1}
        http.expectGET('/api/v1/shipments.json?sid1=shp_shipped_order_ids&sop1=co&sv1=1').respond resp
        d = null
        svc.getOrderShipmentRefs(1).then (data) ->
          d = data
        http.flush()
        expect(d).toEqual ['REF1', 'REF2', 'REF3']

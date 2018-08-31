describe 'ShipmentApp', ->

  beforeEach module('ShipmentApp')

  describe 'ProcessManifestCtrl', ->
    ctrl = svc = scope = q = state = win = null

    beforeEach ->
      module ($provide) ->
        $provide.value('shipmentId',null)
        null #must return null, not the provider in the line above
      inject ($rootScope,$controller,shipmentSvc,$q,$state, $window) ->
        scope = $rootScope.$new()
        svc = shipmentSvc
        win = $window
        ctrl = $controller('ProcessManifestCtrl', {$scope: scope, shipmentSvc: svc})
        q = $q
        state = $state

    describe 'process', ->
      it 'should delegate to service and redirect', ->
        attachment = {id: 2}
        shipment = {id: 1, manufacturerId: 2}
        r = q.defer()
        spyOn(svc,'processTradecardPackManifest').and.returnValue(r.promise)
        scope.process(shipment,attachment, 'Tradecard Manifest', true)
        r.resolve({data: {id: 1}})
        expect(svc.processTradecardPackManifest).toHaveBeenCalledWith(shipment,attachment, 2, true)

      it 'should delegate to booking worksheet service and redirect', ->
        attachment = {id: 2}
        shipment = {id: 1, manufacturerId: 2}
        r = q.defer()
        spyOn(svc,'processBookingWorksheet').and.returnValue(r.promise)
        scope.process(shipment,attachment, 'Booking Worksheet', null)
        r.resolve({data: {id: 1}})
        expect(svc.processBookingWorksheet).toHaveBeenCalledWith(shipment,attachment, 2, null)

      it 'should delegate to booking worksheet service and redirect', ->
        attachment = {id: 2}
        shipment = {id: 1, manufacturerId: 2}
        r = q.defer()
        spyOn(svc,'processManifestWorksheet').and.returnValue(r.promise)
        scope.process(shipment,attachment, 'Manifest Worksheet', true)
        r.resolve({data: {id: 1}})
        expect(svc.processManifestWorksheet).toHaveBeenCalledWith(shipment,attachment, 2, true)

      it 'notifies of error if no service is set up', ->
        spyOn(win, 'alert')
        spyOn(state, 'go')
        scope.process({id: 1}, {}, 'test')
        expect(win.alert).toHaveBeenCalledWith("Unknown worksheet type test selected.")
        expect(state.go).toHaveBeenCalledWith("show", {shipmentId: 1})

    describe 'formatMultiShipmentError', ->
      it 'stringifies order/shipment JSON for error message', ->
        json = {"ord1":["ref1","ref2"], "ord2":["ref3"]}
        expect(scope.formatMultiShipmentError json).toEqual "ord1 (ref1), ord1 (ref2), ord2 (ref3)"
      
  describe 'ShipmentAddOrderCtrl', ->
    ctrl = svc = state = scope = q = null

    beforeEach ->
      module ($provide) ->
        $provide.value('shipmentId',null)
        null #must return null not the provider

      inject ($rootScope,$controller,shipmentSvc,$q, $state) ->
        scope = $rootScope.$new()
        state = $state
        svc = shipmentSvc
        ctrl = $controller('ShipmentAddOrderCtrl', {$scope: scope, shipmentSvc: svc, $state:state})
        q = $q

    describe 'totalToShip', ->
      it 'should total all data types', ->
        o = {order_lines: [
          {quantity_to_ship: 4}
          {quantity_to_ship: 'x'}
          {}
          {quantity_to_ship: '8'}
        ]}
        expect(scope.totalToShip(o)).toEqual 12

    describe 'loadShipment', ->
      it 'should delegate to service and set orders', ->
        available_orders = [{id: 1}, {id: 2}]
        booked_orders = [{id: 3}, {id: 4}]
        spyOn(svc,'getShipment').and.returnValue(q.when({data: {shipment: {id: 10}}}))
        spyOn(svc,'getAvailableOrders').and.returnValue(q.when({data: {available_orders: available_orders}}))
        spyOn(svc,'getBookedOrders').and.returnValue(q.when({data: {booked_orders: booked_orders, lines_available:true}}))

        ctrl.loadShipment(10)
        scope.$apply()

        expect(scope.availableOrders).toEqual available_orders
        expect(scope.bookedOrders).toEqual booked_orders
        expect(scope.linesAvailable).toEqual true

        expect(svc.getShipment).toHaveBeenCalledWith 10
        expect(svc.getAvailableOrders).toHaveBeenCalledWith id:10
        expect(svc.getBookedOrders).toHaveBeenCalledWith id:10

    describe 'getOrderLines', ->
      it "should delegate to service", ->
        ord = {id: 1}
        activeOrder = {id: 99, order_lines: []}
        r = q.defer()
        s = q.defer()
        spyOn(svc,'getOrder').and.returnValue(r.promise)
        spyOn(svc,'getOrderShipmentRefs').and.returnValue(s.promise)
        scope.getOrderLines(ord)
        r.resolve({data: {order: activeOrder}})
        s.resolve([])
        scope.$apply()
        expect(scope.activeOrder).toEqual activeOrder
        expect(svc.getOrder).toHaveBeenCalledWith 1

      it "should set quantity_to_ship to ordln_ordered_qty when no additional shipments are found", ->
        ord = {id: 1}
        r = q.defer()
        s = q.defer()
        spyOn(svc,'getOrder').and.returnValue(r.promise)
        spyOn(svc,'getOrderShipmentRefs').and.returnValue(s.promise)
        scope.getOrderLines(ord)
        r.resolve({data: {order: {id: 99, order_lines: [{ordln_ordered_qty: 10}]}}})
        s.resolve([])
        scope.$apply()
        expect(scope.activeOrder).toEqual {id: 99,order_lines: [{ordln_ordered_qty: 10, quantity_to_ship: 10}]}

      it "prepares data for warning modal when additional shipments are found", ->
        ord = {id: 1}
        r = q.defer()
        spyOn(svc,'getOrderShipmentRefs').and.returnValue(r.promise)
        scope.getOrderLines(ord)
        r.resolve(["REF1", "REF2"])
        scope.$apply()
        expect(scope.activeOrder).toBeNull
        expect(scope.shipmentWarningModalData).toEqual({shipmentsForOrder: ["REF1", "REF2"], orderId: 1})

    describe 'resetQuantityToShip', ->
      it 'should set quantity_to_ship to ordln_ordered_qty', ->
        ord = {order_lines: [{ordln_ordered_qty: 1,quantity_to_ship: 2}, {ordln_ordered_qty: 10,quantity_to_ship: 3}]}
        scope.resetQuantityToShip(ord)
        expect(ord).toEqual {order_lines: [{ordln_ordered_qty: 1,quantity_to_ship: 1}, {ordln_ordered_qty: 10,quantity_to_ship: 10}]}

    describe 'clearQuantityToShip', ->
      it 'should set quantity_to_ship to 0', ->
        ord = {order_lines: [{ordln_ordered_qty: 1,quantity_to_ship: 2}, {ordln_ordered_qty: 10,quantity_to_ship: 3}]}
        scope.clearQuantityToShip(ord)
        expect(ord).toEqual {order_lines: [{ordln_ordered_qty: 1,quantity_to_ship: 0}, {ordln_ordered_qty: 10, quantity_to_ship: 0}]}

    describe 'prorate', ->
      ord = null
      beforeEach ->
        ord = {order_lines: [{quantity_to_ship: 2}, {quantity_to_ship: 1000}]}
      it 'should add percentage', ->
        p = {sign: 'Add', amount: '50'}
        scope.prorate(ord,p)
        expect(ord).toEqual {order_lines: [{quantity_to_ship: 3}, {quantity_to_ship: 1500}]}

      it 'should remove percentage', ->
        p = {sign: 'Remove', amount: 10}
        scope.prorate(ord,p)
        expect(ord).toEqual {order_lines: [{quantity_to_ship: 2}, {quantity_to_ship: 900}]}
      it 'should do nothing if amount is NaN', ->
        p = {sign: 'Add', amount: 'BAD'}
        scope.prorate(ord,p)
        expect(ord).toEqual {order_lines: [{quantity_to_ship: 2}, {quantity_to_ship: 1000}]}

    describe 'addOrderToShipment', ->
      it 'should add to shipment with no lines', ->
        ord = {id: 1,ord_ord_num: 'abc',ord_cust_ord_no: 'def',order_lines: [
          {id: 2, ordln_line_number: '10', ordln_puid: 'SKU1', ordln_pname: 'CHAIR', quantity_to_ship: 3}
          {id: 4, ordln_line_number: '20', ordln_puid: 'SKU2', ordln_pname: 'HAT', quantity_to_ship: 7}
          ]}
        shp = {shp_ref: 'x', id: 3}
        expected = {shp_ref: 'x', id: 3, lines: [
          {shpln_puid: 'SKU1' ,shpln_pname: 'CHAIR', linked_order_line_id: 2, order_lines: [{ord_cust_ord_no: 'def', ordln_line_number: '10'}],shpln_shipped_qty: 3, shpln_manufacturer_address_id: undefined}
          {shpln_puid: 'SKU2' ,shpln_pname: 'HAT', linked_order_line_id: 4, order_lines: [{ord_cust_ord_no: 'def', ordln_line_number: '20'}],shpln_shipped_qty: 7, shpln_manufacturer_address_id: undefined}
          ]}
        scope.addOrderToShipment shp, ord, 'lines'
        expect(shp).toEqual expected

    describe 'addOrderAndSave', ->
      it 'should call add and save', ->
        r = q.defer()
        spyOn(scope,'addOrderToShipment')
        spyOn(svc,'saveShipment').and.returnValue(r.promise)
        shp = {id: 10}
        ord = {id: 7}
        scope.addOrderAndSave(shp,ord)
        r.resolve(shipment: {id: 10})
        expect(scope.addOrderToShipment).toHaveBeenCalled()
        expect(svc.saveShipment).toHaveBeenCalled()

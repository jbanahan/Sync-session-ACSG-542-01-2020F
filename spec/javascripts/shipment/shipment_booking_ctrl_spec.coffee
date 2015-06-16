describe 'ShipmentBookingCtrl', ->
  ctrl = rootScope = svc = state = q = null

  beforeEach module('ShipmentApp')

  beforeEach inject ($rootScope,$controller,shipmentSvc,$q,$state) ->
    rootScope = $rootScope
    svc = shipmentSvc
    state = $state
    ctrl = $controller('ShipmentBookingCtrl', {$state: state, shipmentSvc: svc})
    q = $q

    ctrl.resetLines = () -> ctrl.lines.splice(0, ctrl.lines.length)

  afterEach -> ctrl.resetLines()

  describe 'removeLine', ->
    it 'removes the given line', ->
      line1 = {bkln_quantity:100, bkln_cbms:100}
      line2 = {bkln_order_id:6, bkln_quantity:50, bkln_gross_kgs:100}
      line3 = {bkln_order_line_id:4, bkln_quantity:50, bkln_carton_qty:5}

      ctrl.lines = [line1, line2, line3]

      ctrl.removeLine line2

      expect(ctrl.lines).toContain(line1)
      expect(ctrl.lines).toContain(line3)
      expect(ctrl.lines).toNotContain(line2)

  describe 'loadAvailableOrders', ->
    it 'gets available orders from the service and makes them available', ->
      state.params.shipmentId = 1
      response =
        data:
          available_orders: [1,2,3,4,5]
      spyOn(svc,'getAvailableOrders').andReturn(q.when(response))

      ctrl.loadAvailableOrders()
      rootScope.$apply()

      expect(ctrl.availableOrders).toEqual [1,2,3,4,5]
      expect(svc.getAvailableOrders).toHaveBeenCalledWith({id:1})

  describe 'getOrder', ->
    it 'gets the order from the service and makes converts the lines', ->
      line1 =
        ordln_line_number: 1
        ordln_puid: 'puid'
        ordln_sku: 'sku'
        id: 6
        ordln_ordered_qty: "500"
      line2 =
        ordln_line_number: 2
        ordln_puid: 'puid2'
        ordln_sku: 'sku2'
        id: 7
        ordln_ordered_qty: "5005"
      response =
        data:
          order:
            order_lines:[line1, line2]

      spyOn(svc, 'getOrder').andReturn(q.when(response))

      ctrl.getOrder(1)
      rootScope.$apply()

      expect(ctrl.lines).toEqual [line1, line2].map (line) ->
        ordln_line_number: line.ordln_line_number
        ordln_puid: line.ordln_puid
        ordln_sku: line.ordln_sku
        bkln_order_line_id: line.id
        bkln_quantity: parseInt line.ordln_ordered_qty

  describe 'saveLines', ->
    it 'does not save lines with an order line id and zero quantity', ->
      state.params.shipmentId = 1
      line1 = {bkln_quantity:100, bkln_cbms:100}
      line2 = {bkln_order_id:6, bkln_quantity:50, bkln_gross_kgs:100}
      line3 = {bkln_order_line_id:4, bkln_quantity:0, bkln_carton_qty:5}
      ctrl.lines = [line1, line2, line3]

      spyOn(svc, 'saveBookingLines').andReturn(q.when({}))
      ctrl.saveLines()

      expect(svc.saveBookingLines).toHaveBeenCalledWith([line1, line2], 1)

    it 'flattens product info into the line', ->
      state.params.shipmentId = 1
      line =
        bkln_quantity:100
        bkln_cbms:100
        product:
          originalObject:
            id:1
            name:'name'
            unique_identifier:'uid'

      flat_line =
        bkln_quantity: 100
        bkln_cbms: 100
        bkln_prod_id: 1
        bkln_pname:'name'
        bkln_puid:'uid'

      ctrl.lines = [line]

      spyOn(svc, 'saveBookingLines').andReturn(q.when({}))
      ctrl.saveLines()

      expect(svc.saveBookingLines).toHaveBeenCalledWith([flat_line], 1)

    it 'flattens order info into the line', ->
      state.params.shipmentId = 1
      line =
        bkln_quantity:100
        bkln_cbms:100
        order:
          originalObject:
            id:1
            name:'name'

      flat_line =
        bkln_quantity: 100
        bkln_cbms: 100
        bkln_order_id: 1

      ctrl.lines = [line]

      spyOn(svc, 'saveBookingLines').andReturn(q.when({}))
      ctrl.saveLines()

      expect(svc.saveBookingLines).toHaveBeenCalledWith([flat_line], 1)
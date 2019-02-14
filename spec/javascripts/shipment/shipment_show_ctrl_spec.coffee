describe 'ShipmentShowCtrl', ->
  ctrl = scope = svc = state = q = $window = null

  beforeEach module('ShipmentApp')

  beforeEach ->
    inject ($rootScope,$controller,shipmentSvc,$q,$state) ->
      scope = $rootScope.$new()
      state = $state
      svc = shipmentSvc
      q = $q
      ctrl = $controller('ShipmentShowCtrl', {$scope: scope, shipmentSvc: svc, $state:state, $window: $window})

  describe 'uniqueOrderOptions', ->
    it 'returns an array of order line number and IDs given an array of shipment lines', ->
      line1 = {order_lines: [{order_id: 5, ord_cust_ord_no: 4}]}
      line2 = {order_lines: [
        {order_id: 4, ord_ord_num: 2}
        {order_id: 8, ord_ord_num: 9}
      ]}

      lines = [line1, line2]

      expect(scope.uniqueOrderOptions(lines)).toEqual [{order_id: 5, order_number: 4},{order_id: 4, order_number: 2},{order_id: 8, order_number: 9}]

    it 'selects the correct line order number given more than one', ->
      line1 = {order_lines: [{order_id: 5, ord_cust_ord_no: 4, ord_ord_num: 2}]}
      line2 = {order_lines: [
        {order_id: 4, ord_ord_num: 2, ord_cust_ord_no: null}
        {order_id: 8, ord_ord_num: 9}
      ]}

      lines = [line1, line2]
      expect(scope.uniqueOrderOptions(lines)).toEqual [{order_id: 5, order_number: 4},{order_id: 4, order_number: 2},{order_id: 8, order_number: 9}]

  describe 'removePO', ->
    it 'marks the appropriate lines for deletion given a order number', ->
      line1 = {order_lines: [{order_id: 5, ord_ord_num: 2}]}
      line2 = {order_lines: [
        {order_id: 4, ord_ord_num: 2}
        {order_id: 8, ord_ord_num: 9}
      ]}
      shipment = {id: 1, lines: [line1, line2]}

      markedForDestruction = {id: 1, lines: [ 
        { order_lines: [ { order_id: 5, ord_ord_num: 2 } ] }, 
        { order_lines: [ { order_id: 4, ord_ord_num: 2 }, { order_id: 8, ord_ord_num: 9 } ], _destroy: 'true' }]}

      spyOn(scope, 'saveShipment').and.returnValue(q.when({}))
      spyOn(window, 'confirm').and.returnValue true

      # Note the suddle difference between the order supplied to the removePO function
      #  An order_line can have either ord_ord_num and/or ord_cust_ord_no, but order_number is the only thing here
      scope.removePO(shipment,{order_id: 8, order_number: 9})
      expect(scope.saveShipment).toHaveBeenCalledWith(markedForDestruction)

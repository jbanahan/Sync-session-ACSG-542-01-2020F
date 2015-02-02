describe 'ShipmentApp', () ->

  beforeEach module('ShipmentApp')

  describe 'ProcessManifestCtrl', () ->
    ctrl = svc = scope = q = state = null

    beforeEach ->
      module ($provide) ->
        $provide.value('shipmentId',null)
        null #must return null, not the provider in the line above
      inject ($rootScope,$controller,shipmentSvc,$q,$state) ->
        scope = $rootScope.$new()
        svc = shipmentSvc
        ctrl = $controller('ProcessManifestCtrl', {$scope: scope, shpmentSvc: svc})
        q = $q
        state = $state

    describe 'process', ->
      it 'should delegate to service and redirect', () ->
        attachment = {id:2}
        shipment = {id:1}
        r = q.defer()
        spyOn(svc,'processTradecardPackManifest').andReturn(r.promise)
        scope.process(shipment,attachment)
        r.resolve({data:{id:1}})
        expect(svc.processTradecardPackManifest).toHaveBeenCalledWith(shipment,attachment)

  describe 'ShipmentAddOrderCtrl', ->
    ctrl = svc = scope = q = null

    beforeEach ->
      module ($provide) ->
        $provide.value('shipmentId',null)
        null #must return null not the provider

      inject ($rootScope,$controller,shipmentSvc,$q) ->
        scope = $rootScope.$new()
        svc = shipmentSvc
        ctrl = $controller('ShipmentAddOrderCtrl', {$scope: scope, shpmentSvc: svc})
        q = $q

    describe 'totalToShip', ->
      it 'should total all data types', ->
        o = {order_lines:[
          {quantity_to_ship:4}
          {quantity_to_ship:'x'}
          {}
          {quantity_to_ship:'8'}
        ]}
        expect(scope.totalToShip(o)).toEqual 12
      
    describe 'getAvailableOrders', ->
      it 'should delegate to service and set orders', ->
        r = q.defer()
        spyOn(svc,'getAvailableOrders').andReturn(r.promise)
        scope.getAvailableOrders({id:10})
        r.resolve({data:{available_orders:[{id:1},{id:2}]}})
        scope.$apply()
        expect(scope.availableOrders).toEqual [{id:1},{id:2}]

    describe 'getOrder', ->
      it "should delegate to service", ->
        ord = {id:1}
        r = q.defer()
        spyOn(svc,'getOrder').andReturn(r.promise)
        scope.getOrder(ord)
        r.resolve({data:{order:{id:99,order_lines:[]}}})
        scope.$apply()
        expect(scope.activeOrder).toEqual {id:99,order_lines:[]}
        expect(svc.getOrder).toHaveBeenCalledWith 1
      
      it "should set quantity_to_ship to ordln_ordered_qty", ->
        ord = {id:1}
        r = q.defer()
        spyOn(svc,'getOrder').andReturn(r.promise)
        scope.getOrder(ord)
        r.resolve({data:{order:{id:99,order_lines:[{ordln_ordered_qty:10}]}}})
        scope.$apply()
        expect(scope.activeOrder).toEqual {id:99,order_lines:[{ordln_ordered_qty:10,quantity_to_ship:10}]}

    describe 'resetQuantityToShip', ->
      it 'should set quantity_to_ship to ordln_ordered_qty', ->
        ord = {order_lines:[{ordln_ordered_qty:1,quantity_to_ship:2},{ordln_ordered_qty:10,quantity_to_ship:3}]}
        scope.resetQuantityToShip(ord)
        expect(ord).toEqual {order_lines:[{ordln_ordered_qty:1,quantity_to_ship:1},{ordln_ordered_qty:10,quantity_to_ship:10}]}

    describe 'clearQuantityToShip', ->
      it 'should set quantity_to_ship to 0', ->
        ord = {order_lines:[{ordln_ordered_qty:1,quantity_to_ship:2},{ordln_ordered_qty:10,quantity_to_ship:3}]}
        scope.clearQuantityToShip(ord)
        expect(ord).toEqual {order_lines:[{ordln_ordered_qty:1,quantity_to_ship:0},{ordln_ordered_qty:10,quantity_to_ship:0}]}        
    
    describe 'prorate', ->
      ord = null
      beforeEach ->
        ord = {order_lines:[{quantity_to_ship:2},{quantity_to_ship:1000}]}
      it 'should add percentage', ->
        p = {sign:'Add',amount:'50'}
        scope.prorate(ord,p)
        expect(ord).toEqual {order_lines:[{quantity_to_ship:3},{quantity_to_ship:1500}]}

      it 'should remove percentage', ->
        p = {sign:'Remove',amount:10}
        scope.prorate(ord,p)
        expect(ord).toEqual {order_lines:[{quantity_to_ship:2},{quantity_to_ship:900}]}        
      it 'should do nothing if amount is NaN', ->
        p = {sign:'Add',amount:'BAD'}
        scope.prorate(ord,p)
        expect(ord).toEqual {order_lines:[{quantity_to_ship:2},{quantity_to_ship:1000}]}

    describe 'addOrderToShipment', ->
      it 'should add to shipment with no lines', ->
        ord = {id:1,ord_ord_num:'abc',ord_cust_ord_no:'def',order_lines:[
          {id:2,ordln_line_number:'10',ordln_puid:'SKU1',ordln_pname:'CHAIR',quantity_to_ship:3}
          {id:4,ordln_line_number:'20',ordln_puid:'SKU2',ordln_pname:'HAT',quantity_to_ship:7}
          ]}
        shp = {shp_ref:'x',id:3}
        expected = {shp_ref:'x',id:3,lines:[
          {shpln_line_number:1,shpln_puid:'SKU1',shpln_pname:'CHAIR',linked_order_line_id:2,order_lines:[{ord_cust_ord_no:'def',ordln_line_number:'10'}],shpln_shipped_qty:3}
          {shpln_line_number:2,shpln_puid:'SKU2',shpln_pname:'HAT',linked_order_line_id:4,order_lines:[{ord_cust_ord_no:'def',ordln_line_number:'20'}],shpln_shipped_qty:7}
          ]}
        scope.addOrderToShipment shp, ord, null
        expect(shp).toEqual expected

    describe 'addOrderAndSave', ->
      it 'should call add and save', ->
        r = q.defer()
        spyOn(scope,'addOrderToShipment')
        spyOn(svc,'saveShipment').andReturn(r.promise)
        shp = {id:10}
        ord = {id:7}
        scope.addOrderAndSave(shp,ord)
        r.resolve(shipment:{id:10})
        expect(scope.addOrderToShipment).toHaveBeenCalled()
        expect(svc.saveShipment).toHaveBeenCalled()

  describe 'ShipmentEditCtrl', ->
    ctrl = svc = scope = q = null

    beforeEach ->
      module ($provide) ->
        $provide.value('shipmentId',null)
        null #must return null not the provider

      inject ($rootScope,$controller,shipmentSvc,$q) ->
        scope = $rootScope.$new()
        svc = shipmentSvc
        ctrl = $controller('ShipmentEditCtrl', {$scope: scope, shpmentSvc: svc})
        q = $q
      

    describe "loadShipment", () ->
      it "should delegate to getShipment and toggle state", () ->
        data = {shipment:{id:1,shp_ref:'REF'}}
        r = q.defer()
        spyOn(svc, 'getShipment').andReturn(r.promise)
        scope.loadShipment(1)
        r.resolve({data:data})
        scope.$apply()
        expect(svc.getShipment).toHaveBeenCalledWith(1)
        expect(scope.shp).toEqual data.shipment

    describe 'saveShipment', ->
      it 'should delegate to service', ->
        shp = {shp_ref:'OLD'}
        data = {shipment:{id:1,shp_ref:'REF'}}
        r = q.defer()
        spyOn(svc,'saveShipment').andReturn(r.promise)
        scope.saveShipment shp
        r.resolve {data:data}
        scope.$apply()
        expect(svc.saveShipment).toHaveBeenCalledWith shp
        expect(scope.shp).toEqual data.shipment
    
    describe 'loadParties', ->
      it 'should delegate to service', ->
        data = {x:'y'}
        promise = {
          success: (fn) ->
            fn(data,null,null,null)
            this
          error: (fn) ->
            this
        }
        spyOn(svc,'getParties').andReturn(promise)
        scope.loadParties()
        expect(svc.getParties).toHaveBeenCalled()
        expect(scope.parties).toEqual data

    describe 'init', ->
      it 'should call load shipment and load parties', ->
        spyOn(scope,'loadParties')
        spyOn(scope,'loadShipment')
        scope.init(3)
        expect(scope.loadParties).toHaveBeenCalled()
        expect(scope.loadShipment).toHaveBeenCalledWith(3)
      
    describe 'addContainer', ->
      it 'should addContainer and set isNew field', ->
        shp = {containers:[]}
        scope.addContainer(shp)
        expect(shp).toEqual {containers:[{isNew:true}]}
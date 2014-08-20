describe 'ShipmentApp', () ->

  beforeEach module('ShipmentApp')

  describe 'shipmentSvc', () ->
    http = svc = null

    beforeEach inject((shipmentSvc,$httpBackend) ->
      svc = shipmentSvc
      http = $httpBackend
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'getShipment', () ->
      it 'should get shipment from server', () ->
        resp = {shipment:{id:1}}
        http.expectGET('/api/v1/shipments/1.json?include=order_lines,attachments').respond resp
        shp = null
        svc.getShipment(1).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

    describe 'saveShipment', () ->
      it "should remove zero quantity lines that don't already have an ID", ->
        start = {ship_ref:'REF',lines:[{shpln_shipped_qty:'0'}]}
        expected = {ship_ref:'REF',lines:[]}
        http.expectPOST('/api/v1/shipments',{shipment:expected,include:'order_lines,attachments'}).respond {shipment:expected}
        svc.saveShipment(start)
        http.flush()

      it "should flag zero quantity lines with an ID for destroy", ->
        start = {ship_ref:'REF',lines:[{id:7,shpln_shipped_qty:'0'}]}
        expected = {ship_ref:'REF',lines:[{id:7,shpln_shipped_qty:'0',_destroy:true}]}
        http.expectPOST('/api/v1/shipments',{shipment:expected,include:'order_lines,attachments'}).respond {shipment:expected}
        svc.saveShipment(start)
        http.flush()        

      it "should keep lines with a quantity", ->
        start = {ship_ref:'REF',lines:[{id:7,shpln_shipped_qty:'5'},{shpln_shipped_qty:'6'}]}
        expected = {ship_ref:'REF',lines:[{id:7,shpln_shipped_qty:'5'},{shpln_shipped_qty:'6'}]}
        http.expectPOST('/api/v1/shipments',{shipment:expected,include:'order_lines,attachments'}).respond {shipment:expected}
        svc.saveShipment(start)
        http.flush()                

      it 'should send post for create', () ->
        base = {shp_ref:'REF'}
        resp = {shipment:{id:1}}
        http.expectPOST('/api/v1/shipments',{shipment:base,include:'order_lines,attachments'}).respond resp
        shp = null
        svc.saveShipment(base).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

      it 'should send put for update', () ->
        base = {shp_ref:'REF',id:1}
        resp = {shipment:{id:1}}
        http.expectPUT('/api/v1/shipments/1.json',{shipment:base,include:'order_lines,attachments'}).respond resp
        shp = null
        svc.saveShipment(base).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp      

    describe 'getParties', () ->
      it 'should query companies api', () ->
        resp = {'importers':[{id:1}]}
        http.expectGET('/api/v1/companies?roles=importer,carrier').respond resp
        d = null
        svc.getParties().success (data) ->
          d = data
        http.flush()
        expect(d).toEqual resp  

    describe 'getAvailableOrders', ->
      it 'should query orders api', ->
        resp = {'orders':[{id:1}]}
        http.expectGET('/api/v1/orders?fields=ord_ord_num,ord_ven_name&page=2').respond resp
        d = null
        svc.getAvailableOrders(2).success (data) ->
          d = data
        http.flush()
        expect(d).toEqual resp

    describe 'getOrder', ->
      it 'should query orders api', ->
        resp = {order:{id:1,ord_ord_num:'x'}}
        http.expectGET('/api/v1/orders/1').respond resp
        d = null
        svc.getOrder(1).success (data) ->
          d = data
        http.flush()
        expect(d).toEqual resp

    describe 'addOrderToShipment', ->
      it 'should add to shipment with no lines', ->
        ord = {id:1,ord_ord_num:'abc',ord_cust_ord_no:'def',lines:[
          {id:2,ordln_line_number:'10',ordln_puid:'SKU1',ordln_pname:'CHAIR'}
          {id:4,ordln_line_number:'20',ordln_puid:'SKU2',ordln_pname:'HAT'}
          ]}
        shp = {shp_ref:'x',id:3}
        expected = {shp_ref:'x',id:3,lines:[
          {shpln_line_number:1,shpln_puid:'SKU1',shpln_pname:'CHAIR',linked_order_line_id:2,order_lines:[{ord_cust_ord_no:'def',ordln_line_number:'10'}]}
          {shpln_line_number:2,shpln_puid:'SKU2',shpln_pname:'HAT',linked_order_line_id:4,order_lines:[{ord_cust_ord_no:'def',ordln_line_number:'20'}]}
          ]}
        svc.addOrderToShipment shp, ord, null
        expect(shp).toEqual expected
      
    describe 'processTradecardPackManifest', ->
      it 'should submit', ->
        resp = {shipment:{id:1}}
        http.expectPOST('/api/v1/shipments/1/process_tradecard_pack_manifest',{attachment_id:2,include:'order_lines,attachments'}).respond resp
        shp = null
        svc.processTradecardPackManifest({id:1},{id:2}).then (data) ->
          shp = data.data
        http.flush()
        expect(shp).toEqual resp

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
      
  describe 'ShipmentEditCtrl', () ->
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
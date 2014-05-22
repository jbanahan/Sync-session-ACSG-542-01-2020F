describe 'HMApp', () ->
  beforeEach module('HMApp')

  describe 'service', () ->
    svc = http = null

    beforeEach inject((hmService,$httpBackend) ->
      svc = hmService
      http = $httpBackend
    )
    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'recalc', ->
      it 'should recalc values for line', ->
        ln = {unit_cost:10,quantity:1000} #these numbers expose a JS bug fixed by BigNumber
        svc.recalc ln
        expect(ln.invoice_value).toEqual 10000
        expect(ln.adjusted_value).toEqual 10049

    describe 'getLines', ->
      expected_url = response_obj = null
      beforeEach ->
        expected_url = '/api/v1/commercial_invoices.json?page=99&per_page=20&sid1=ci_imp_syscode&sop1=eq&sv1=HENNE'
        response_obj = {page:99,per_page:20,results:[
          {ci_invoice_number:'123',ci_imp_syscode:'HENNE',lines:[{cil_line_number:1,cil_units:230,cil_value:420.90,ent_unit_price:1.83}]},
          {ci_invoice_number:'124',ci_imp_syscode:'HENNE',lines:[{cil_line_number:1,cil_units:230,cil_value:420.90,ent_unit_price:1.83}]}
        ]}
      it 'should make request', () ->
        http.expectGET(expected_url).respond(response_obj)
        svc.getLines 99
        http.flush()

      it 'should append line results to data', () ->
        lines = null
        http.expectGET(expected_url).respond(response_obj)
        p = svc.getLines 99
        p.success (d,s,h,c) ->
          lines = d.lines
        http.flush()
        expect(lines.length).toEqual 2
        expect(lines[0].po_number).toEqual '123'
        expect(lines[1].po_number).toEqual '124'

      it 'should search by PO number', () ->
        expected_url = '/api/v1/commercial_invoices.json?page=99&per_page=20&sid1=ci_imp_syscode&sid2=ci_invoice_number&sop1=eq&sop2=co&sv1=HENNE&sv2=123'
        http.expectGET(expected_url).respond(response_obj)
        svc.getLines 99, {poNumber:'123'}
        http.flush()

    describe 'saveLine', ->
      ln = expected_obj = null
      beforeEach ->
        ln = {
          po_number:'101631'
          hts_code:'1234567890'
          cartons:4
          docs_rec_date:'2014-02-25'
          docs_ok_date:'2014-02-26'
          quantity:230
          currency:'USD'
          unit_cost:1.83
          invoice_value:420.90
          adjusted_value:422.63
          origin_country:'CN'
          gross_weight:123
          net_weight:122
          issue_codes:'AB'
          comment:'COMM',
          mid:'MID1'
          reporting_quantity:103
          reporting_uom:'PCS'
        }
        expected_obj = {
          commercial_invoice:{
            ci_invoice_number:ln.po_number
            ci_imp_syscode:svc.sys_code
            ci_invoice_value_foreign:420.90
            ci_total_quantity:4
            ci_total_quantity_uom:'CTNS'
            ci_docs_received_date:'2014-02-25'
            ci_docs_ok_date:'2014-02-26'
            ci_issue_codes:'AB'
            ci_rater_comments:'COMM'
            ci_mfid:'MID1'
            lines:[{
                cil_line_number:1
                cil_units:230
                cil_value_foreign:422.63
                ent_unit_price:1.83
                cil_currency:'USD'
                cil_country_origin_code:'CN'
                tariffs:[{
                  cit_gross_weight:123
                  cit_hts_code:'1234567890'
                  cit_classification_qty_1:103
                  cit_classification_uom_1:'PCS'
                  cit_classification_qty_2:122
                  cit_classification_uom_2:'KGS'
                }]
              }
            ]
          }
        }

      it 'should set saving flag while in flight', () ->
        http.expectPOST('/api/v1/commercial_invoices.json',expected_obj).respond(expected_obj) #not the real response value from the API
        svc.saveLine ln
        expect(ln.saving).toBeTruthy()
        http.flush()

      it 'should create new object if line.id is not set', () ->
        http.expectPOST('/api/v1/commercial_invoices.json',expected_obj).respond(expected_obj) #not the real response value from the API
        svc.saveLine ln
        http.flush()

      it 'should update if line.id is set', () ->
        ln.id = 100
        expected_obj.commercial_invoice.id = 100 #should have id set
        http.expectPUT('/api/v1/commercial_invoices/100.json',expected_obj).respond(expected_obj)
        svc.saveLine ln
        http.flush()

      it "should set ci_line_id if is set", () ->
        ln.ci_line_id = 10
        ln.id = 100
        expected_obj.commercial_invoice.id = 100 #should have id set
        expected_obj.commercial_invoice.lines[0].id = 10
        http.expectPUT('/api/v1/commercial_invoices/100.json',expected_obj).respond(expected_obj)
        svc.saveLine ln
        http.flush()

      it "should add line to return data on success", () ->
        returnObj = jQuery.extend(true, {}, expected_obj)
        returnObj.commercial_invoice.id = 1
        returnObj.commercial_invoice.lines[0].id = 2
        http.expectPOST('/api/v1/commercial_invoices.json',expected_obj).respond(returnObj)
        p = svc.saveLine ln
        myLine = null
        p.success (d,s,h,c) ->
          myLine = d.line
        http.flush()
        expect(myLine.id).toEqual 1
        expect(myLine.po_number).toEqual ln.po_number
        expect(myLine.quantity).toEqual ln.quantity
        expect(myLine.unit_cost).toEqual ln.unit_cost
        expect(myLine.invoice_value).toEqual ln.invoice_value
        expect(myLine.adjusted_value).toEqual ln.adjusted_value
        expect(myLine.ci_line_id).toEqual 2
        expect(myLine.currency).toEqual 'USD'

  describe 'controller', () ->
    ctrl = $scope = svc = null
    
    beforeEach inject(($rootScope,$controller,hmService) ->
      $scope = $rootScope.$new()
      svc = hmService
      ctrl = $controller('HMPOLineController',{$scope:$scope,hmService:svc})
    )

    it "should initialize with empty PO Line", () ->
      expect($scope.poLine).toEqual({})

    describe 'saveLine', ->
      promise = data = null
      beforeEach ->
        data = {line:{id:10}}
        promise = {
          success: (fn) ->
            fn(data,null,null,null)
            this
          error: (fn) ->
            this

        }
        spyOn(svc,'saveLine').andReturn(promise)

      it 'should delegate to service', ->
        ln = {id:99}
        $scope.saveLine(ln)
        expect(svc.saveLine).toHaveBeenCalledWith(ln)

      it 'should add to recentLines', () ->
        ln = {id:99}
        $scope.saveLine(ln)
        expect(svc.saveLine).toHaveBeenCalledWith(ln)
        expect($scope.recentLines.length).toEqual 1
        expect($scope.recentLines[0]).toEqual data.line

      it 'should replace existing in recentLines', () ->
        $scope.recentLines = [{id:data.line.id,r:'other'}]
        ln = {id:99}
        $scope.saveLine(ln)
        expect(svc.saveLine).toHaveBeenCalledWith(ln)
        expect($scope.recentLines.length).toEqual 1
        expect($scope.recentLines[0]).toEqual data.line        
      

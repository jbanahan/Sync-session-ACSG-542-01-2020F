describe 'ProductSvc', ->

  beforeEach module('ProductApp')

  describe 'productSvc', ->

    http = svc = q = scope = officialTariffSvc = commentSvc = null

    beforeEach inject((_productSvc_,_commentSvc_,_officialTariffSvc_,$httpBackend,$q,$rootScope) ->
      svc = _productSvc_
      http = $httpBackend
      q = $q
      scope = $rootScope
      officialTariffSvc = _officialTariffSvc_
      commentSvc = _commentSvc_
      spyOn(commentSvc,'injectComments')
    )

    afterEach ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'getProduct', ->
      it 'should get product from the server', ->
        resp = {product: {id: 1}}
        http.expectGET('/api/v1/products/1.json?include=attachments').respond resp
        
        prod = null
        svc.getProduct(1).then (httpResp) ->
          prod = httpResp.data

        http.flush()

        scope.$apply()

        expect(prod).toEqual resp

      it 'should inject comments', ->
        resp = {product: {id: 1}}
        http.expectGET('/api/v1/products/1.json?include=attachments').respond resp
        
        prod = null
        svc.getProduct(1).then (httpResp) ->
          prod = httpResp.data

        http.flush()

        scope.$apply()

        expect(commentSvc.injectComments).toHaveBeenCalled()

      it 'should strip out prod_ent_type_id', ->
        # we only want to deal with prod_ent_type
        resp = {product: {id: 1, prod_ent_type: 'Shoes', prod_ent_type_id: 5}}
        http.expectGET('/api/v1/products/1.json?include=attachments').respond resp
        
        prod = null
        svc.getProduct(1).then (httpResp) ->
          prod = httpResp.data

        http.flush()

        scope.$apply()

        expect(prod.product.prod_ent_type).toEqual 'Shoes'
        expect(prod.product.prod_ent_type_id).toBeUndefined()

      it 'should cache product', ->
        resp = {product: {id: 1}}

        #first call should be from server
        http.expectGET('/api/v1/products/1.json?include=attachments').respond resp
        
        
        svc.getProduct(1).then (httpResp) ->
          #don't care about first response
          null

        http.flush()

        prod = null
        svc.getProduct(1).then (cacheResp) ->
          prod = cacheResp.data

        scope.$apply()

        expect(prod).toEqual resp

    describe 'loadProduct', ->
      it 'should reload product from server every time', ->
        resp = {product: {id: 1}}

        #both calls should be from server
        http.expectGET('/api/v1/products/1.json?include=attachments').respond resp

        prod1 = null
        svc.loadProduct(1).then (httpResp) ->
          prod1 = httpResp.data

        http.flush()
        scope.$apply()

        expect(prod1).toEqual resp

        http.expectGET('/api/v1/products/1.json?include=attachments').respond resp
        prod2 = null
        svc.loadProduct(1).then (httpResp) ->
          prod2 = httpResp.data

        http.flush()
        scope.$apply()

        expect(prod2).toEqual resp
        

    describe 'saveProduct', ->
      it 'should save existing product', ->
        base = {id: 1, prod_uid: 'abc'}
        resp = {product: {id: 1}}
        http.expectPUT('/api/v1/products/1.json',{product: base, include: 'attachments'}).respond resp
        prod = null
        svc.saveProduct(base).then (data) ->
          prod = data.data
        http.flush()
        expect(prod).toEqual resp

      it 'should save new product', ->
        base = {prod_uid: 'abc'}
        resp = {product: {id: 1}}
        http.expectPOST('/api/v1/products.json',{product: base, include: 'attachments'}).respond resp
        prod = null
        svc.saveProduct(base).then (data) ->
          prod = data.data
        http.flush()
        expect(prod).toEqual resp

    describe 'autoClassify', ->

      it 'should add autoClassifications to existing components', ->
        product = {id:1,classifications: [{
          class_cntry_iso:'US', tariff_records: [
            {id:1000,hts_line_number:'1',hts_hts_1:'1234568888'}
          ]
          },
          {class_cntry_iso:'CA', tariff_records: [
            {hts_line_number:'2'}
            {hts_line_number:'1'}
          ]},
          {class_cntry_iso:'MX'},
          {class_cntry_iso:'CN', tariff_records: [
            {hts_line_number:'2'}
          ]},
          {class_cntry_iso:'KR'}
        ]}

        otResp = {
          US:{iso:'US',hts:[{code:'1234568888'},{code:'1234568889'}]},
          CA:{iso:'CA',hts:[{code:'1234569999'}]},
          MX:{iso:'MX',hts:[{code:'1234567777'}]},
          CN:{iso:'CN',hts:[{code:'1234564444'}]}
        }

        promise = {
          then: (handler) ->
            handler(otResp)
        }
        spyOn(officialTariffSvc,'autoClassify').andReturn(promise)

        svc.autoClassify(product, product.classifications[0].tariff_records[0])

        cls = product.classifications

        # USA 
        expect(cls[0].tariff_records[0].autoClassifications).toEqual otResp.US.hts

        # Canada
        expect(cls[1].tariff_records[0].autoClassifications).toBeUndefined()
        expect(cls[1].tariff_records[1].autoClassifications).toEqual otResp.CA.hts

        # Mexico
        expect(cls[2].tariff_records[0].autoClassifications).toEqual otResp.MX.hts
        expect(cls[2].tariff_records[0].hts_line_number).toEqual '1'

        # China
        expect(cls[3].tariff_records[0].autoClassifications).toBeUndefined()
        expect(cls[3].tariff_records[1].autoClassifications).toEqual otResp.CN.hts        
        expect(cls[3].tariff_records[1].hts_line_number).toEqual '1'

        # Korea
        expect(cls[4].tariff_records).toBeUndefined()

      it 'should toggle flag on base classification', ->
        product = {id:1,classifications: [{
          class_cntry_iso:'US', tariff_records: [
            {id:1000,hts_line_number:'1',hts_hts_1:'1234568888'}
          ]
          }]
        }
        d = q.defer()

        spyOn(officialTariffSvc,'autoClassify').andReturn(d.promise)

        d.resolve({}) #don't care about value returned

        svc.autoClassify(product,product.classifications[0].tariff_records[0])

        expect(product.autoClassifying).toBeTruthy()
          
        scope.$apply()
      
        expect(product.autoClassifying).toBeFalsy()
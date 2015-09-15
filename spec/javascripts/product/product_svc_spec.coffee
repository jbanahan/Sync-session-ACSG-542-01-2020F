describe 'ProductSvc', ->

  beforeEach module('ProductApp')

  describe 'productSvc', ->

    http = svc = q = scope = null

    beforeEach inject((_productSvc_,$httpBackend,$q,$rootScope) ->
      svc = _productSvc_
      http = $httpBackend
      q = $q
      scope = $rootScope
    )

    afterEach ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'getProduct', ->
      it 'should get product from the server', ->
        resp = {product: {id: 1}}
        http.expectGET('/api/v1/products/1.json').respond resp
        
        prod = null
        svc.getProduct(1).then (httpResp) ->
          prod = httpResp.data

        http.flush()

        expect(prod).toEqual resp

      it 'should cache product', ->
        resp = {product: {id: 1}}

        #first call should be from server
        http.expectGET('/api/v1/products/1.json').respond resp
        
        
        svc.getProduct(1).then (httpResp) ->
          #don't care about first response
          null

        http.flush()

        prod = null
        svc.getProduct(1).then (httpResp) ->
          prod = httpResp.data

        scope.$apply()

        expect(prod).toEqual resp

    describe 'saveProduct', ->
      it 'should save existing product', ->
        base = {id: 1, prod_uid: 'abc'}
        resp = {product: {id: 1}}
        http.expectPUT('/api/v1/products/1.json',{product: base}).respond resp
        prod = null
        svc.saveProduct(base).then (data) ->
          prod = data.data
        http.flush()
        expect(prod).toEqual resp

      it 'should save new product'
      
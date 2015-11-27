describe 'VariantSvc', ->
  beforeEach module('ProductApp')

  describe 'variantSvc', ->
    $httpBackend = svc = q = scope = null

    beforeEach inject((_variantSvc_,_$httpBackend_,$q,$rootScope) ->
      svc = _variantSvc_
      $httpBackend = _$httpBackend_
      q = $q
      scope = $rootScope
    )

    afterEach ->
      $httpBackend.verifyNoOutstandingExpectation()
      $httpBackend.verifyNoOutstandingRequest()

    describe 'getVariant', ->
      it 'should get variant from server', ->
        resp = {variant: {id: 1}}
        $httpBackend.expectGET('/api/v1/variants/1.json').respond resp

        variant = null
        svc.getVariant(1).then (httpResp) ->
          variant = httpResp.data

        $httpBackend.flush()

        scope.$apply()

        expect(variant).toEqual resp

      it 'should cache multiple variants', ->
        r1 = {variant: {id: 1}}
        r2 = {variant: {id: 2}}

        $httpBackend.expectGET('/api/v1/variants/1.json').respond r1
        $httpBackend.expectGET('/api/v1/variants/2.json').respond r2

        # load the objects up into the cache
        svc.getVariant(1).then (httpResp) ->
          null
        svc.getVariant(2).then (httpResp) ->
          null
        $httpBackend.flush()

        v1 = null
        v2 = null

        svc.getVariant(1).then (cacheResp) ->
          v1 = cacheResp.data
        svc.getVariant(2).then (cacheResp) ->
          v2 = cacheResp.data

        scope.$apply()

        expect(v1).toEqual r1
        expect(v2).toEqual r2

    describe 'loadVariant', ->
      it 'should get variant from server every time', ->
        resp = {variant: {id: 1}}
        $httpBackend.expectGET('/api/v1/variants/1.json').respond resp

        variant = null
        svc.loadVariant(1).then (httpResp) ->
          variant = httpResp.data

        $httpBackend.flush()

        scope.$apply()

        expect(variant).toEqual resp

        $httpBackend.expectGET('/api/v1/variants/1.json').respond resp

        v2 = null
        svc.loadVariant(1).then (httpResp) ->
          v2 = httpResp.data

        $httpBackend.flush()

        scope.$apply()

        expect(v2).toEqual resp
      
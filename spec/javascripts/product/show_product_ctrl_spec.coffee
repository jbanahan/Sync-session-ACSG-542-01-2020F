describe 'ShowProductCtrl', ->
  beforeEach module('ProductApp')

  ctrl = scope = productSvc = cdSvc = setupDataSvc = $q = null

  beforeEach inject(($controller,$rootScope,_productSvc_,_chainDomainerSvc_,_setupDataSvc_,_$q_) ->
    scope = $rootScope.$new()
    productSvc = _productSvc_
    cdSvc = _chainDomainerSvc_
    setupDataSvc = _setupDataSvc_
    $q = _$q_
    ctrl = $controller('ShowProductCtrl', {$scope: scope, productSvc: productSvc, productId: null})

  )

  describe 'load', ->
    it 'should load product, dictionary, setup_data', ->
      prod = {id: 1}
      prodResp = $q.defer()
      spyOn(productSvc,'getProduct').andReturn(prodResp.promise)
      
      dict = new DomainDictionary()
      dictResp = $q.defer()
      spyOn(cdSvc,'withDictionary').andReturn(dictResp.promise)

      setupData = {regions: ['x'], import_countries: {'US': {id: 1}}}
      sdResp = $q.defer()
      spyOn(setupDataSvc,'getSetupData').andReturn(sdResp.promise)

      scope.load(1)

      expect(scope.loadingFlag).toEqual("loading")

      dictResp.resolve(dict)
      prodResp.resolve({data: {product: prod}})
      sdResp.resolve(setupData)
      scope.$apply()

      expect(scope.loadingFlag).toBeNull()
      expect(scope.product).toEqual(prod)
      expect(scope.dictionary).toEqual(dict)
      expect(scope.regions).toEqual(setupData.regions)
      expect(scope.import_countries).toEqual(setupData.import_countries)

  describe 'save', ->
    it "should save product", ->
      startProd = {id: 1}
      finishProd = {id: 1, other: 'x'}
      prodResp = $q.defer()
      spyOn(productSvc,'saveProduct').andReturn(prodResp.promise)

      scope.save(startProd)

      spyOn(scope,'load')

      prodResp.resolve({data: {product: finishProd}})

      scope.$apply()

      expect(scope.load).toHaveBeenCalledWith(1)

  describe 'classificationByISO', ->
    product = null
    beforeEach ->
      product = {
        classifications: [
          {id:99,class_cntry_iso:'US'}
          {id:100,class_cntry_iso:'CA'}
        ]
      }

    it "should load found value", ->
      expect(scope.classificationByISO('US',product)).toEqual(product.classifications[0])

    it "should return null if value not found", ->
      expect(scope.classificationByISO('CN',product)).toBeNull()

  describe 'classificationsWithoutRegion', ->
    it "should find countries not in a region", ->
      regions = [
        {countries:[{iso_code:'US'}]}
        {countries:[{iso_code:'US'},{iso_code:'CA'}]}
      ]
      product = {
        classifications: [
          {id:99,class_cntry_iso:'US'}
          {id:100,class_cntry_iso:'CA'}
          {id:101,class_cntry_iso:'CN'}
        ]
      }

      expect(scope.classificationsWithoutRegion(regions,product)).toEqual([product.classifications[2]])
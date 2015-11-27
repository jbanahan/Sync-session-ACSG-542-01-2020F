describe 'ShowVariantCtrl', ->
  beforeEach module('ProductApp')

  ctrl = scope = productSvc = variantSvc = cdSvc = setupDataSvc = $q = null

  beforeEach inject(($controller,$rootScope,_productSvc_,_variantSvc_,_chainDomainerSvc_,_$q_) ->
    scope = $rootScope.$new()
    productSvc = _productSvc_
    variantSvc = _variantSvc_
    cdSvc = _chainDomainerSvc_
    $q = _$q_
    ctrl = $controller('ShowVariantCtrl', {$scope: scope, variantSvc: variantSvc, productSvc: productSvc, productId: null, variantId: null})
  )

  describe 'load', ->
    it 'should load product, dictionary, variant', ->
      prod = {id: 1}
      prodResp = $q.defer()
      spyOn(productSvc,'getProduct').andReturn(prodResp.promise)

      variant = {id: 2}
      varResp = $q.defer()
      spyOn(variantSvc,'getVariant').andReturn(varResp.promise)

      dict = new DomainDictionary()
      dictResp = $q.defer()
      spyOn(cdSvc,'withDictionary').andReturn(dictResp.promise)

      scope.load(1,2)

      expect(scope.loadingFlag).toEqual("loading")

      dictResp.resolve(dict)
      prodResp.resolve({data: {product: prod}})
      varResp.resolve({data: {variant: variant}})
      scope.$apply()

      expect(scope.loadingFlag).toBeNull()
      expect(scope.product).toEqual(prod)
      expect(scope.dictionary).toEqual(dict)
      expect(scope.variant).toEqual(variant)

  describe 'reloadVariant', ->
    it 'should reload variant & product without dictionary', ->
      prod = {id: 1}
      prodResp = $q.defer()
      spyOn(productSvc,'loadProduct').andReturn(prodResp.promise)

      variant = {id: 2}
      varResp = $q.defer()
      spyOn(variantSvc,'loadVariant').andReturn(varResp.promise)

      scope.reloadVariant(1,2)

      expect(scope.loadingFlag).toEqual("loading")

      prodResp.resolve({data: {product: prod}})
      varResp.resolve({data: {variant: variant}})
      scope.$apply()

      expect(scope.loadingFlag).toBeNull()
      expect(scope.product).toEqual(prod)
      expect(scope.variant).toEqual(variant)

  describe 'events', ->
    it 'should reload on chain:state-toggle-change:finish', ->
      scope.product = {id:1}
      scope.variant = {id:2}
      spyOn(scope,'reloadVariant')

      scope.$root.$broadcast 'chain:state-toggle-change:finish'

      expect(scope.reloadVariant).toHaveBeenCalledWith(1,2)
      
      
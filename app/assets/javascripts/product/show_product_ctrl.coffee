angular.module('ProductApp').controller 'ShowProductCtrl', ['$scope','productSvc','chainErrorHandler','chainDomainerSvc','setupDataSvc','productId',($scope,productSvc,chainErrorHandler,chainDomainerSvc,setupDataSvc,productId) ->
  $scope.eh = chainErrorHandler
  $scope.eh.responseErrorHandler = (rejection) ->
    $scope.notificationMessage = null

  $scope.product = null
  $scope.dictionary = null

  $scope.load = (id) ->
    $scope.loadingFlag = "loading"
    chainDomainerSvc.withDictionary().then (dict) ->
      $scope.dictionary = dict
      productSvc.getProduct(id).then (resp) ->
        $scope.product = resp.data.product
        $scope.loadingFlag = null

    setupDataSvc.getSetupData().then (sd) ->
      $scope.regions = sd.regions
      $scope.import_countries = sd.import_countries

  $scope.save = (product) ->
    $scope.loadingFlag = "loading"
    productSvc.saveProduct(product).then (resp) ->
      $scope.productEditObject = null
      $scope.load(resp.data.product.id)
        # $scope.product = resp.data.product
        # $scope.loadingFlag = null

  $scope.prepProductEditObject = (product) ->
    $scope.productEditObject = angular.copy(product)

  # view helper methods
  $scope.classificationByISO = (iso,product) ->
    return null unless product && product.classifications
    for cls in product.classifications
      cci = cls.class_cntry_iso
      cci = '' unless cci
      return cls if cci.toLowerCase() == iso.toLowerCase()
    return null

  $scope.classificationsWithoutRegion = (regions,product) ->
    return [] unless product && regions && product.classifications && product.classifications.length > 0
    assigned_iso_arrays = regions.map (r) ->
      r.countries.map (c) ->
        c.iso_code.toLowerCase()
    # flatten assigned_iso_arrays
    assigned_isos = [].concat.apply([],assigned_iso_arrays)

    return $.grep(product.classifications, (cls) ->
      if $.inArray(cls.class_cntry_iso.toLowerCase(),assigned_isos) == -1
        return cls
      else
        return null
    )

  #initializer
  if productId
    $scope.load(productId)
]
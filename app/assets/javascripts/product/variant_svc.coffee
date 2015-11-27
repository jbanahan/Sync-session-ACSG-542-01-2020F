angular.module('ProductApp').factory 'variantSvc', ['$http','$q',($http,$q) ->
  variantCache = {}

  variantLoadSuccessHandler = (resp) ->
    variantCache[resp.data.variant.id] = resp.data.variant

  return {
    # get variant from server or in memory cache
    getVariant: (id) ->
      cachedVariant = variantCache[parseInt(id)]
      if cachedVariant
        deferred = $q.defer()
        deferred.resolve {data: {variant: cachedVariant}}
        return deferred.promise
      else
        return this.loadVariant(id)


    # get variant from server, and load into cache
    loadVariant: (id) ->
      deferred = $q.defer()
      $http.get('/api/v1/variants/'+id+'.json').then(variantLoadSuccessHandler).then (resp) ->
        deferred.resolve {data: {variant: variantCache[parseInt(id)]}}
      deferred.promise
  }
]
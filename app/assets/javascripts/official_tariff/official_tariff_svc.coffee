angular.module('ChainComponents').factory 'officialTariffSvc', ['$http','$q',($http,$q) ->
  return {
    getTariff: (isoCode, htsCode) ->
      deferred = $q.defer()

      success = (resp) ->
        deferred.resolve(resp.data.official_tariff)
      
      err = (resp) ->
        deferred.resolve(null)

      $http.get('/api/v1/official_tariffs/find/'+isoCode+'/'+htsCode).then(success,err)

      deferred.promise

    autoClassify: (htsCode) ->
      deferred = $q.defer()

      $http.get('/official_tariffs/auto_classify/'+htsCode.replace(/[^\d]/g,'')).then (resp) ->
        rawData = resp.data
        returnObj = {}
        for c in rawData
          returnObj[c.iso] = c

        deferred.resolve(returnObj)

      deferred.promise
        
  }
]
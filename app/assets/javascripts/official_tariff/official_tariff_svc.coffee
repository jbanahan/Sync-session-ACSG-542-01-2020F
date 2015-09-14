angular.module('ChainComponents').factory 'officialTariffSvc', ['$http','$q',($http,$q) ->
  return {
    getTariff: (iso_code, hts_code) ->
      deferred = $q.defer()

      success = (resp) ->
        deferred.resolve(resp.data.official_tariff)
      
      err = (resp) ->
        deferred.resolve(null)

      $http.get('/api/v1/official_tariffs/find/'+iso_code+'/'+hts_code).then(success,err)

      deferred.promise
  }
]
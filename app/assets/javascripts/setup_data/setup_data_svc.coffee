angular.module('ChainComponents').factory 'setupDataSvc', ['$http','$q',($http,$q) ->

  cachedSetupData = null

  return {
    getSetupData: ->
      deferred = $q.defer()

      if cachedSetupData
        deferred.resolve(cachedSetupData)
      else
        $http.get('/api/v1/setup_data').then (resp) ->
          cachedSetupData = {import_countries:{},regions:[]}

          for ic in resp.data.import_countries
            cachedSetupData.import_countries[ic.iso_code] = ic

          for r in resp.data.regions
            country_objects = []
            for iso in r.countries
              if cachedSetupData.import_countries[iso] then country_objects.push(cachedSetupData.import_countries[iso])
            r.countries = country_objects
            cachedSetupData.regions.push(r)

          deferred.resolve(cachedSetupData)

      deferred.promise
  }
]

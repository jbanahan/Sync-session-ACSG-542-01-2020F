# Chain specific domainer service and directives
cDom = angular.module('ChainDomainer',['Domainer'])

cDom.factory('chainDomainerSvc',['$http','domainerSvc',($http,domainerSvc) ->
  domainDAOChain = {
    makeDictionary: (worker) ->
      $http.get('/api/v1/model_fields').then (resp) ->
        data = resp.data
        dict = new DomainDictionary()
        recordTypes = {}
        for rt in data.recordTypes
          dict.registerRecordType(rt)
          recordTypes[rt.uid] = rt
        for fld in data.fields
          fld.recordType = recordTypes[fld.record_type_uid]
          dict.registerField(fld)
        worker(dict)
  }

  setupDone = false
  return {
    withDictionary: ->
      if !setupDone
        domainerSvc.setLocalDAO domainDAOChain
        domainerSvc.setRemoteDAO domainDAOChain
        domainerSvc.setExpirationChecker new DomainExpirationCheckerLocal()
        setupDone = true

      domainerSvc.withDictionary()
  }
])
dMod = angular.module('Domainer', [])

dMod.factory('domainerSvc', ['$q',($q) ->
  localDAO = null
  remoteDAO = null
  expChecker = null
  domainer = null
  return {
    setLocalDAO: (d) ->
      localDAO = d
      domainer = null
    setRemoteDAO: (d) ->
      remoteDAO = d
      domainer = null
    setExpirationChecker: (d) ->
      expChecker = d
      domainer = null

    withDictionary: ->
      unless domainer
        domainer = new Domainer(new DomainDataAccessSetup(localDAO,remoteDAO,expChecker))
      deferred = $q.defer()
      domainer.withDictionary (dict) ->
        deferred.resolve dict
        
      deferred.promise

  }
])
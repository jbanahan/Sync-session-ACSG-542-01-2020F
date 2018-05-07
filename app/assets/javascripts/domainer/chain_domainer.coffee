# Chain specific domainer service and directives
cDom = angular.module('ChainDomainer',['Domainer'])

cDom.factory('chainDomainerSvc',['$http','domainerSvc',($http,domainerSvc) ->
  domainDAOChainFunc = ->
    cachedPromise = null
    return {
      makeDictionary: (worker) ->
        if !cachedPromise
          cachedPromise = $http.get('/api/v1/model_fields')
        cachedPromise.then (resp) ->
          data = resp.data
          dict = new DomainDictionary()
          recordTypes = {}
          recordTypes["custom"] = {uid: "custom", label: "Custom"}
          for rt in data.recordTypes
            dict.registerRecordType(rt)
            recordTypes[rt.uid] = rt
          dict.registerRecordType(recordTypes["custom"])
          for fld in data.fields
            if fld.select_options
              fld.selectOpts = fld.select_options.map (opt) ->
                {value:opt[0],label:opt[1]}
              # put in blank value at top of list
              fld.selectOpts.unshift {value:'',label:''}

            # If a field has a cdef_uid, register it using the cdef_uid (prefixing it w/ a star, so it's obvious that it's custom def and to
            # also avoid potential collisions w/ real uids).  This allows us to list custom fields by a unique identifier in field lists directly
            # alongside "real" non-custom uids.
            if fld.cdef_uid
              # The reason we're cloning the fld is that we don't want the object we're registring to have a recordType (otherwise, it 
              # since we're registring it twice, requests for fields of that type will return two instances of the field - which we don't want).
              # Basically, we're saying this field is of a "blank" recordType and the only way it should be looked up is via a directly field
              # reference by cdef_uid.
              cloned = angular.fromJson(angular.toJson(fld))
              cloned.recordType = recordTypes["custom"]
              dict.registerField(cloned, "*#{cloned.cdef_uid}")

            fld.recordType = recordTypes[fld.record_type_uid]
            dict.registerField(fld)
            

          worker(dict)
      }

  domainDAOChain = domainDAOChainFunc()

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

angular.module('ChainComponents').service 'fieldValidatorSvc', ['$http','$q',($http,$q) ->
  {
    validate: (field, value) ->
      deferred = $q.defer()

      $http.get('/field_validator_rules/validate',{params: {mf_id:field.uid,value:value}}).then (resp) ->
        # nesting the legacy response in an object to make it easier to work with downstream
        respObj = {errors:resp.data}
        deferred.resolve(respObj)

      deferred.promise
  }
]
app = angular.module('CoreObjectValidationResultsApp',['ChainComponents'])

app.factory 'coreObjectValidationResultsSvc', ['$http',($http) ->
  {
    states: ["Pass","Review","Fail","Skipped"]
    #converts rule state to Bootstrap contextual value
    # so stateToBootstrap('btn','Pass') returns 'btn-success'
    stateToBootstrap: (prefix,state) ->
      r = 'default'
      switch state
        when 'Pass' then r = 'success'
        when 'Review' then r = 'warning'
        when 'Fail' then r = 'danger'
      prefix+'-'+r

    stateToGlyphicon: (state) ->
      r = ''
      switch state
        when 'Pass' then r = 'glyphicon-ok'
        when 'Review' then r = 'glyphicon-user'
        when 'Fail' then r = 'glyphicon-remove'
        when 'Skipped' then r = 'glyphicon-minus'
      r

    loadRuleResult: (pluralObject, objectId) ->
      $http.get('/' + pluralObject + '/' + objectId + '/validation_results.json')

    saveRuleResult: (result,ruleResult) ->
      p = $http.put('/business_validation_rule_results/'+ruleResult.id+'.json',{business_validation_rule_result:ruleResult})
      p.success (data) ->
        result.state = data.save_response.validatable_state
        new_result = data.save_response.rule_result
        for bvr in result.bv_results
          for rr, i in bvr.rule_results
            if rr.id == new_result.id
              bvr.rule_results[i] = new_result
              bvr.state = data.save_response.result_state

      p
  }
]

app.controller 'coreObjectValidationResultsCtrl', ['$scope','coreObjectValidationResultsSvc',($scope,coreObjectValidationResultsSvc) ->
  $scope.svc = coreObjectValidationResultsSvc
  $scope.ruleResultToEdit = null
  $scope.editRuleResult = (rr) ->
    $scope.ruleResultToEdit = rr
  $scope.saveRuleResult = (rr) ->
    p = coreObjectValidationResultsSvc.saveRuleResult $scope.result, rr
    p.success () ->
      $scope.editRuleResult data.save_response.rule_result

  $scope.loadObject = (pluralObject, objectId) ->
    p = coreObjectValidationResultsSvc.loadRuleResult pluralObject, objectId
    p.success (data) ->
      $scope.result = data['business_validation_result']
]

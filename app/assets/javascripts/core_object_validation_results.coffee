app = angular.module('CoreObjectValidationResultsApp',['ChainComponents', 'angularMoment'])

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
      if prefix
        return prefix+'-'+r
      else
        return r

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

app.directive 'coreObjectValidationPanel', ['coreObjectValidationResultsSvc', (coreObjectValidationResultsSvc)->
  {
    restrict: 'E'
    scope: {
      pluralObject: '@'
      objectId: '='
    }
    templateUrl: '/partials/core_object_validation_results/core_object_validation_panel.html'
    link: (scope,el,attrs) ->
      loadObject = (path,id) ->
        scope.loading = 'loading'
        coreObjectValidationResultsSvc.loadRuleResult(path,id).success (data) ->
          scope.result = data['business_validation_result']
          scope.loading = null

      scope.stateToBootstrap = (prefix, obj) ->
        state = 'none'
        state = obj.state if obj
        coreObjectValidationResultsSvc.stateToBootstrap(prefix,state)

      scope.editRuleResult = (rr) ->
        # we're stringify / parsing below to make sure we get a clean object to edit, not the one in the parent
        # that way if the user clicks close, the edits they made disappear
        scope.resultToEdit = JSON.parse(JSON.stringify(rr))
        $('#business-rules-edit').modal('show')
        return null # must not return dom object or angular gets upset

      scope.saveResult = (rr) ->
        scope.loading = 'loading'
        $('#business-rules-edit').modal('hide')
        p = coreObjectValidationResultsSvc.saveRuleResult scope.result, rr
        p.success () ->
          loadObject(scope.pluralObject,scope.objectId)

      scope.$watch 'objectId', (nv,ov) ->
        if nv
          loadObject(scope.pluralObject,nv)

      scope.states = coreObjectValidationResultsSvc.states
  }
]

app.directive 'stateIcon', [ ->
  {
    restrict: 'E'
    scope: {
      state: '='
    }
    template: "<i class='fa {{stateClasses(state)}}' title='{{state}}'></i>"
    link: (scope,el,attrs) ->
      scope.stateClasses = (state) ->
        iconClass = ''
        colorClass = 'text-muted'
        switch state
          when 'Pass'
            iconClass = 'fa-check'
            colorClass = 'text-success'
          when 'Review'
            iconClass = 'fa-warning'
            colorClass = 'text-warning'
          when 'Fail'
            iconClass = 'fa-times'
            colorClass = 'text-danger'
          when 'Skipped'
            iconClass = 'fa-minus'
        
        return "" + iconClass + " " + colorClass

  }
]
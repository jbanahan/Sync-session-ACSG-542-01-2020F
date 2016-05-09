describe 'CoreObjectValidationResultsApp', () ->
  beforeEach module('CoreObjectValidationResultsApp')

  describe 'service', () ->
    svc = http = null
    beforeEach inject(($httpBackend,coreObjectValidationResultsSvc) ->
      svc = coreObjectValidationResultsSvc
      http = $httpBackend
    )

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'stateToBootstrap', () ->
      it 'should convert Fail', () ->
        expect(svc.stateToBootstrap('text','Fail')).toEqual 'text-danger'
      it 'should convert Review', () ->
        expect(svc.stateToBootstrap('text','Review')).toEqual 'text-warning'
      it 'should convert Pass', () ->
        expect(svc.stateToBootstrap('text','Pass')).toEqual 'text-success'
      it 'should default to default', () ->
        expect(svc.stateToBootstrap('text','other')).toEqual 'text-default'

    describe 'saveRuleResult', () ->
      it "should save", () ->
        rr = {id:99}
        returned_rr = {id:99,overridden_at:'something'}
        result = {state:'x',bv_results:[{state:'y',rule_results:[{id:1},rr]}]}
        response = {save_response:{validatable_state:'Pass',result_state:'Fail',rule_result:returned_rr}}
        http.expectPUT('/business_validation_rule_results/99.json',{business_validation_rule_result:rr}).respond response
        svc.saveRuleResult(result,rr)
        http.flush()
        expect(result.state).toEqual 'Pass'
        expect(result.bv_results[0].state).toEqual 'Fail'
        expect(result.bv_results[0].rule_results[0]).toEqual {id:1} #does not change
        expect(result.bv_results[0].rule_results[1]).toEqual returned_rr
        expect(result.bv_results[0].rule_results.length).toEqual 2

    describe 'loadRuleResult', () ->
      it "should load", () ->
        returnVal = {id:1,state:'x'}
        http.expectGET('/entries/1/validation_results.json').respond returnVal
        promise = svc.loadRuleResult('entries', 1)
        resolvedPromise = null
        promise.success (data) ->
          resolvedPromise = data
        http.flush()
        expect(resolvedPromise).toEqual returnVal

    describe 'cancelOverride', () ->
      it "calls cancel-override PUT route", () ->
        rr = {id: 1}
        http.expectPUT('/business_validation_rule_results/1/cancel_override').respond {}
        svc.cancelOverride rr
        http.flush()

    describe 'rerunValidations', () ->
      it "calls validate POST route", () ->
        http.expectPOST('/api/v1/entries/1/validate.json').respond {}
        svc.rerunValidations 'entries', 1
        http.flush()
        
  describe 'controller', () ->
    ctrl = svc = $scope = q = null

    beforeEach inject(($rootScope,$controller,$q,coreObjectValidationResultsSvc) ->
      $scope = $rootScope.$new()
      svc = coreObjectValidationResultsSvc
      ctrl = $controller('coreObjectValidationResultsCtrl',{$scope:$scope,srService:svc})
      q = $q
      svc.pluralObject = {x: 'x'}
      svc.objectId = {y: 'y'}
    )

    describe 'editRuleResult', () ->
      it "should set ruleResultToEdit", () ->
        x = {a:'b'}
        $scope.editRuleResult(x)
        expect($scope.ruleResultToEdit).toEqual x

      it "should clear ruleResultChanged flag", () ->
        $scope.ruleResultChanged = true
        x = {a:'b'}
        $scope.editRuleResult(x)
        expect($scope.ruleResultChanged).toBe null

    describe 'cancelOverride', () ->
      it "deletes result and ruleResultToEdit", () ->
        $scope.result = "foo"
        $scope.ruleResultToEdit = "bar"
        $scope.cancelOverride {}
        expect($scope.result).toBe null
        expect($scope.ruleResultToEdit).toBe null
      
      it "calls the service's cancelOverride ", () ->
        deferredOverride = q.defer()
        deferredOverride.resolve {a:'a'}
        spyOn(svc, 'cancelOverride').andReturn deferredOverride.promise

        deferredLoad = q.defer()
        loadResolution = {b:'b'}
        deferredLoad.resolve loadResolution
        spyOn($scope, 'loadObject').andReturn deferredLoad.promise
        
        svc.pluralObject = {c: 'c'}
        svc.objectId = {d: 'd'}
        rr = {id:100}
        returnVal = null
        $scope.cancelOverride(rr).then (rv) ->
          returnVal = rv
        
        $scope.$apply()

        expect(returnVal).toEqual loadResolution
        expect(svc.cancelOverride).toHaveBeenCalledWith(rr)
        expect($scope.loadObject).toHaveBeenCalledWith(svc.pluralObject, svc.objectId)

      it "logs an error if pluralObject or objectId not found in coreObjectValidationResultsSvc", () ->
        svc.pluralObject = null
        rr = {id:100}
        spyOn(svc, 'cancelOverride').andCallThrough()
        spyOn(console, 'log')
        $scope.cancelOverride(rr)

        expect(svc.cancelOverride).not.toHaveBeenCalled()
        expect(console.log).toHaveBeenCalledWith("ERROR: pluralObject or objectId not found in coreObjectValidationResultsSvc!")

    describe 'rerunValidations', () ->
      it "calls the service's rerunValidations, settings and updating panel", () ->
        deferredRerun = q.defer()
        deferredRerun.resolve {a:'a'}
        spyOn(svc, 'rerunValidations').andReturn deferredRerun.promise

        deferredLoad = q.defer()
        loadResolution = {b:'b'}
        deferredLoad.resolve loadResolution
        spyOn($scope, 'loadObject').andReturn deferredLoad.promise

        spyOn($scope, 'setPanel')

        svc.pluralObject = {c: 'c'}
        svc.objectId = {d: 'd'}
        returnVal = null
        $scope.rerunValidations()
        $scope.$apply()

        expect(svc.rerunValidations).toHaveBeenCalledWith(svc.pluralObject, svc.objectId)
        expect($scope.loadObject).toHaveBeenCalledWith(svc.pluralObject, svc.objectId)
        expect($scope.ruleResultToEdit).toEqual null
        expect($scope.setPanel).toHaveBeenCalledWith("Business Rules are being reevaluated.", "info")
        expect($scope.setPanel).toHaveBeenCalledWith("Business Rules have been reevaluated.", "info")

    describe 'markRuleResultChanged', () ->
      it "sets ruleResultChanged flag", () ->
        $scope.ruleResultChanged = true
        $scope.markRuleResultChanged()
        expect($scope.ruleResultChanged).toBe true
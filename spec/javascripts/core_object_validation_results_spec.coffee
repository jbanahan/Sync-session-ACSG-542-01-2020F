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


    describe 'stateToGlyphicon', () ->
      it 'should convert Pass', () ->
        expect(svc.stateToGlyphicon('Pass')).toEqual 'glyphicon-ok'
      it 'should convert Review', () ->
        expect(svc.stateToGlyphicon('Review')).toEqual 'glyphicon-user'
      it 'should convert Fail', () ->
        expect(svc.stateToGlyphicon('Fail')).toEqual 'glyphicon-remove'
      it 'should convert Skipped', () ->
        expect(svc.stateToGlyphicon('Skipped')).toEqual 'glyphicon-minus'
      it 'should not convert Other', () ->
        expect(svc.stateToGlyphicon('Other')).toEqual ''

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
        
  describe 'controller', () ->
    ctrl = svc = $scope = null

    beforeEach inject(($rootScope,$controller,coreObjectValidationResultsSvc) ->
      $scope = $rootScope.$new()
      svc = coreObjectValidationResultsSvc
      ctrl = $controller('coreObjectValidationResultsCtrl',{$scope:$scope,srService:svc})
    )

    describe 'editRuleResult', () ->
      it "should set ruleResultToEdit", () ->
        x = {a:'b'}
        $scope.editRuleResult(x)
        expect($scope.ruleResultToEdit).toEqual x
    

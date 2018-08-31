describe 'FieldValidatorSvc', ->

  beforeEach module('ChainComponents')

  svc = http = $q = scope = null
  beforeEach inject((_fieldValidatorSvc_,$httpBackend,_$q_,$rootScope) ->
    svc = _fieldValidatorSvc_
    http = $httpBackend
    $q = _$q_
    scope = $rootScope
  )


  afterEach ->
    http.verifyNoOutstandingExpectation()
    http.verifyNoOutstandingRequest()

  describe 'validate', ->
    it 'should validate when no errors', ->
      resp = []
      
      fld = {uid:'prod_uid'}
      val = 'abc'

      http.expectGET('/field_validator_rules/validate?mf_id=prod_uid&value=abc').respond resp

      respondedWith = null
      svc.validate(fld,val).then (obj) ->
        respondedWith = obj

      expect(http.flush).not.toThrow()

      scope.$apply()

      expect(respondedWith.errors).toEqual []


    it 'should validate with errors', ->
      resp = ['error message 1', 'message 2']


      fld = {uid:'prod_uid'}
      val = 'abc'

      http.expectGET('/field_validator_rules/validate?mf_id=prod_uid&value=abc').respond resp

      respondedWith = null
      svc.validate(fld,val).then (obj) ->
        respondedWith = obj

      expect(http.flush).not.toThrow()

      scope.$apply()

      expect(respondedWith.errors).toEqual resp

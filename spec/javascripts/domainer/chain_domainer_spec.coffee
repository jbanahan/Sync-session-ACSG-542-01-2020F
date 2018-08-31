describe 'ChainDomainer', ->
  beforeEach module('ChainDomainer')

  describe 'chainDomainerSvc', ->

    svc = dSvc = http = scope = null
    beforeEach inject((_chainDomainerSvc_, _domainerSvc_,_$httpBackend_,_$rootScope_) ->
      dSvc = _domainerSvc_
      svc = _chainDomainerSvc_
      http = _$httpBackend_
      scope = _$rootScope_
    )

    afterEach ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    it 'should load dictionary from server', ->
      httpResp = {recordTypes: [{uid:'Product',label:'Prod'}], fields:[{uid:'prod_uid',label:'Unique',record_type_uid:'Product'}]}
      http.expectGET('/api/v1/model_fields').respond httpResp
      
      dict = null
      svc.withDictionary().then (d) ->
        dict = d

      expect(http.flush).not.toThrow()
      scope.$apply()

      expect(dict.fields.prod_uid.label).toEqual 'Unique'
      expect(dict.recordTypes['Product'].label).toEqual 'Prod'

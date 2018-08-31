describe 'SetupDataSvc', ->
  beforeEach module('ChainComponents')

  describe 'setupDataSvc', ->
    http = svc = $q =  null

    beforeEach inject((_setupDataSvc_,_$httpBackend_,_$q_) ->
      svc = _setupDataSvc_
      http = _$httpBackend_
      $q = _$q_
    )

    afterEach ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe 'getSetupData', ->
      it 'should get setup data from server', ->
        resp = {
          import_countries:[{id:1,iso_code:'US',name:'USA'}]
          regions:[{id:1,name:'NA',countries:['US']}]
        }
        http.expectGET('/api/v1/setup_data').respond resp

        # index countries by ISO for easier lookup
        formattedResult = {import_countries:{},regions:{}}
        formattedResult.import_countries.US = resp.import_countries[0]

        # replace region countries with objects
        formattedResult.regions = [{id:1,name:'NA',countries:[formattedResult.import_countries.US]}]

        sd = null
        svc.getSetupData().then (sdResp) ->
          sd = sdResp

        http.flush()

        expect(sd).toEqual formattedResult

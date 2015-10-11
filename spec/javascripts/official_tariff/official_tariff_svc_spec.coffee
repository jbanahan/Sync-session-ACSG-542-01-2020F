describe "OfficialTariffSvc", ->
  beforeEach module("ChainComponents")

  officialTariffSvc = http = null
  beforeEach inject((_officialTariffSvc_,_$httpBackend_) ->
    officialTariffSvc = _officialTariffSvc_
    http = _$httpBackend_
  )

  describe 'getTariff', ->
    it "should get tariff", ->
      resp = {official_tariff: {id:1, hts_code:'1234567890'}}
      http.expectGET('/api/v1/official_tariffs/find/US/1234567890').respond resp

      t = null
      officialTariffSvc.getTariff('US','1234567890').then (ot) ->
        t = ot

      http.flush()

      expect(t).toEqual resp.official_tariff

    it "should handle 404 by returning null", ->
      http.expectGET('/api/v1/official_tariffs/find/US/1234567890').respond(404,'')

      t = 'something'
      officialTariffSvc.getTariff('US','1234567890').then (ot) ->
        t = ot

      http.flush()

      expect(t).toBeNull()

  describe 'autoClassify', ->
    it 'should get results as an object keyed by ISO', ->
      resp = [
        {iso:'US',hts:[{code:'1234567890'},{code:'1234560987'}]}
        {iso:'CA',hts:[{code:'1234560000'}]}
      ]
      expected = {
        US: {iso:'US',hts:[{code:'1234567890'},{code:'1234560987'}]},
        CA: {iso:'CA',hts:[{code:'1234560000'}]}
      }

      http.expectGET('/official_tariffs/auto_classify/1234569999').respond resp

      got = null
      officialTariffSvc.autoClassify('1234569999').then (r) ->
        got = r

      http.flush()

      expect(got).toEqual expected

    it 'should sanitize tariff number', ->
      resp = [{iso:'US',hts:[]}]

      http.expectGET('/official_tariffs/auto_classify/1234567890').respond resp

      officialTariffSvc.autoClassify('1234.56.7890')

      http.flush()
    
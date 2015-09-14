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
describe 'Domainer', ->
  beforeEach module('Domainer')

  describe 'withDictionary', ->
    domainerSvc = $q = scope = null

    beforeEach inject((_domainerSvc_,_$q_,_$rootScope_) ->
      domainerSvc = _domainerSvc_
      $q = _$q_
      scope = _$rootScope_
    )

    it "should return promise with dictionary", ->
      expected = new DomainDictionary()
      pt = new DomainDAOPassthrough(expected)
      expirationChecker = new DomainExpirationCheckerLocal()

      domainerSvc.setLocalDAO(pt)
      domainerSvc.setRemoteDAO(pt)
      domainerSvc.setExpirationChecker(expirationChecker)

      dict = null
      domainerSvc.withDictionary().then (dictResp) ->
        dict = dictResp

      scope.$apply()

      expect(dict).toEqual expected
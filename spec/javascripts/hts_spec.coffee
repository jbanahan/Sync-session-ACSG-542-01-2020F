describe "HtsApp", () ->
  beforeEach module('HtsApp')
  
  describe 'HtsCtrl', () ->
    http = ctrl = scope = countriesResponse = chaptersResponse = null

    beforeEach inject ($injector) ->
      http = $injector.get('$httpBackend')
      scope = $injector.get('$rootScope')
      $ctrl = $injector.get('$controller')
      ctrl = $ctrl('HtsCtrl', {$scope: scope})
      countriesResponse = {countries:[{iso:'US',name:'USA',view:true},{iso:'CA',name:'Canada',view:true}]}
      chaptersResponse = {headings:[1,2,3]}
      headingsResponse = {sub_headings:[6, 7, 8]}
      
      http.whenGET('/hts/subscribed_countries.json').respond(200,countriesResponse)
      http.whenGET('/hts/US.json').respond(200,{chapters:[1,2,3]})
      http.whenGET('/hts/US/chapter/1.json').respond(200,chaptersResponse)
      http.whenGET('/hts/US/heading/15.json').respond(200,headingsResponse)

    afterEach () ->
      http.verifyNoOutstandingExpectation()
      http.verifyNoOutstandingRequest()

    describe "loadSubscribedCountries", () ->
      it "should load countries by default", () ->
        scope.loadSubscribedCountries()
        http.flush()
        expect(scope.countries).toEqual countriesResponse.countries
        expect(scope.country.iso).toEqual 'US'

      it "should load first country's chapters", () ->
        scope.loadSubscribedCountries()
        http.flush()
        expect(scope.country.iso).toEqual 'US'
        expect(scope.chapters).toEqual [1,2,3]

    describe "loadChapter", () ->
      it "should assign headings to the given chapter", () ->
        chapter = {num: 1, headings: []}
        country = {iso: "US"}
        scope.loadChapter(country, chapter)
        http.flush()
        expect(chapter.headings).toEqual [1,2,3]

    describe "loadHeading", () ->
      it "should assign subheadings to the given heading", () ->
        chapter = {num: 1, headings: [2, 3, 4]}
        country = {iso: "US"}
        heading = {num: 5, sub_headings: []}
        scope.loadHeading(country,chapter,heading)
        http.flush()
        expect(heading.sub_headings).toEqual [6, 7, 8]


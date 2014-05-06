htsApp = angular.module('HtsApp',[])
htsApp.controller 'HtsCtrl', ['$scope','$http',($scope,$http) ->
  $scope.chapters = []
  $scope.viewMode = 'base'
  $scope.country = ""
  $scope.countries = []

  $scope.loadSubscribedCountries = () ->
    $scope.countries = []
    $http.get('/hts/subscribed_countries.json').success((data)->
      $scope.countries = data.countries
      $scope.subscribed_isos = (country.iso for country in $scope.countries)
      $scope.country = $scope.countries[0]
    )

  loadCountry = (country) ->
    $scope.chapters = []
    if country.iso in $scope.subscribed_isos
      $scope.viewMode = 'base'
      $http.get('/hts/'+country.iso+'.json').success((data) ->
        $scope.chapters = data.chapters
      )
    else
      $scope.viewMode = 'more-info'

  $scope.loadChapter = (country,chapter) ->
    $http.get('/hts/'+country.iso+'/chapter/'+chapter.num+'.json').success((data) ->
      chapter.headings = data.headings
    )

  $scope.loadHeading = (country,chapter,heading) ->
    $http.get('/hts/'+country.iso+'/heading/'+chapter.num+heading.num+'.json').success((data) ->
      heading.sub_headings = data.sub_headings
    )

  $scope.loadSubscribedCountries()

  $scope.$watch('country',(newVal,oldVal) ->
    loadCountry newVal if newVal && (oldVal!=newVal)
  )
  @
]

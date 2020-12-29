htsApp = angular.module('HtsApp',[])
htsApp.controller 'HtsCtrl', ['$scope','$http',($scope,$http) ->
  $scope.chapters = []
  $scope.viewMode = 'base'
  $scope.country = ""
  $scope.countries = []
  $scope.limitedMode = false

  $scope.loadSubscribedCountries = () ->
    $scope.countries = []
    $http.get('/hts/subscribed_countries.json').then ((resp)->
      $scope.limitedMode = resp.data.limited_mode
      $scope.countries = resp.data.countries
      $scope.subscribed_isos = (country.iso for country in $scope.countries)
      $scope.country = $scope.countries[0]
    )

  loadCountry = (country) ->
    $scope.chapters = []
    if (country.iso in $scope.subscribed_isos) and (country.view == true)
      successCallback = (resp) ->
        $scope.viewMode = 'base'
        $scope.chapters = resp.data.chapters
      errorCallback = (resp) ->
        $scope.viewMode = 'more-info'

      $http.get('/hts/'+country.iso+'.json').then(successCallback, errorCallback)
    else
      $scope.viewMode = 'more-info'

  $scope.loadChapter = (country,chapter) ->
    successCallback = (resp) ->
      chapter.headings = resp.data.headings
    
    errorCallback = (resp) ->
        $scope.viewMode = 'more-info'
    
    $http.get('/hts/'+country.iso+'/chapter/'+chapter.num+'.json').then(successCallback,errorCallback)

  $scope.loadHeading = (country,chapter,heading) ->
    successCallback = (resp) ->
      heading.sub_headings = resp.data.sub_headings
    
    errorCallback = (resp) ->
      $scope.viewMode = 'more-info'
    
    $http.get('/hts/'+country.iso+'/heading/'+chapter.num+heading.num+'.json').then(successCallback,errorCallback)

  $scope.loadSubscribedCountries()

  $scope.$watch('country',(newVal,oldVal) ->
    loadCountry newVal if newVal && (oldVal!=newVal)
  )
  @
]

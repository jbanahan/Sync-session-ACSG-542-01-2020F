htsApp = angular.module('HtsApp',[])
htsApp.controller 'HtsCtrl', ['$scope','$http',($scope,$http) ->
  $scope.countries = [
    {iso:'US',name:'United States'}
    {iso:'CA',name:'Canada'}
    {iso:'MX',name:'Mexico'}
  ]
  $scope.country = $scope.countries[0]
  $scope.chapters = []

  $scope.viewMode = 'base'

  loadCountry = (country) ->
    $scope.chapters = []
    if country.iso == 'US' || country.iso == 'CA'
      $scope.viewMode = 'base'
      $http.get('/hts/'+country.iso).success((data) ->
        $scope.chapters = data.chapters
      )
    else
      $scope.viewMode = 'more-info'

  $scope.loadChapter = (country,chapter) ->
    $http.get('/hts/'+country.iso+'/chapter/'+chapter.num).success((data) ->
      chapter.headings = data.headings
    )

  $scope.loadHeading = (country,chapter,heading) ->
    $http.get('/hts/'+country.iso+'/heading/'+chapter.num+heading.num).success((data) ->
      heading.sub_headings = data.sub_headings
    )

  loadCountry($scope.country)

  $scope.$watch('country',(newVal,oldVal) ->
    loadCountry newVal if newVal && (oldVal!=newVal)
  )
  @
]

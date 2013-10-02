htsApp = angular.module('HtsApp',[])
htsApp.controller 'HtsCtrl', ['$scope','$http',($scope,$http) ->
  $scope.countries = [
    {iso:'US',name:'United States'}
    {iso:'CA',name:'Canada'}
    {iso:'AU',name:'Australia'}
    {iso:'CL',name:'Chile'}
    {iso:'CN',name:'China'}
    {iso:'HK',name:'Hong Kong'}
    {iso:'ID',name:'Indonesia'}
    {iso:'IT',name:'Italy'}
    {iso:'JP',name:'Japan'}
    {iso:'KR',name:'Korea, Republic of'}
    {iso:'MO',name:'Macao'}
    {iso:'MY',name:'Malaysia'}
    {iso:'MX',name:'Mexico'}
    {iso:'NZ',name:'New Zealand'}
    {iso:'NO',name:'Norway'}
    {iso:'PE',name:'Peru'}
    {iso:'PH',name:'Philippines'}
    {iso:'RU',name:'Russian Federation'}
    {iso:'SG',name:'Singapore'}
    {iso:'TW',name:'Taiwan'}
    {iso:'TH',name:'Thailand'}
    {iso:'TR',name:'Turkey'}
    {iso:'VN',name:'Vietnam'}
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

root = exports ? this
importedFileApp = angular.module('ImportedFileApp',['ChainComponents']).config(['$routeProvider', ($routeProvider) ->
  $routeProvider.
    when('/:fileId',{templateUrl:'/templates/imported_file.html',controller:'ImportedFileController'}).
    when('/:fileId/:page',{templateUrl:'/templates/imported_file.html',controller:'ImportedFileController'})
])

importedFileApp.controller 'ImportedFileController', ['$scope', '$routeParams', '$http', '$location', 'chainSearchOperators', ($scope,$routeParams,$http,$location,chainSearchOperators) ->

  #find object in array by mfid
  findByMfid = (ary,mfid) ->
    for m in ary
      return m if m.mfid==mfid
    return null

  $scope.errors = []
  $scope.notices = []
  pg = parseInt $routeParams.page
  pg = 1 if isNaN(pg) or pg<1
  $scope.page = pg
  $scope.importedFile = {}
  $scope.searchResult = {}

  $scope.operators = chainSearchOperators.ops
  $scope.criterionToAdd = null
  #add criterion to model
  $scope.addCriterion = (toAddId) ->
    toAdd = {value:''}
    mf = findByMfid $scope.importedFile.model_fields, toAddId
    toAdd.mfid = mf.mfid
    toAdd.datatype = mf.datatype
    toAdd.label = mf.label
    toAdd.operator = $scope.operators[toAdd.datatype][0].operator
    $scope.importedFile.search_criterions.push toAdd

  #remove criterion from model
  $scope.removeCriterion = (crit) ->
    criterions = $scope.importedFile.search_criterions
    criterions.splice(criterions.indexOf(crit),1)

  $scope.showPreviewBox = false
  $scope.previewResults = []

  $scope.showEmailCurrent = false
  $scope.emailCurrentSettings = {to:'',subject:'[chain.io] Current File Data',body:''}

  $scope.enableEmailCurrent = () ->
    $scope.showEmailCurrent = true

  $scope.disableEmailCurrent = () ->
    $scope.showEmailCurrent = false

  $scope.sendEmailCurrent = () ->
    countryIds = []
    for c in $scope.importedFile.available_countries
      countryIds.push c.id if c.selected
    $scope.emailCurrentSettings.extra_countries = countryIds
    $scope.disableEmailCurrent()
    $http.post('/imported_files/'+$scope.importedFile.id+"/email_file",$scope.emailCurrentSettings).success(() ->
      $scope.notices.push "Your file has been scheduled and will be emailed soon."
    ).error(() ->
      $scope.errors.push "There was an error emailing this file. Please contact support."
    )


  $scope.process = () ->
    $scope.showPreviewBox = false
    $http.post('/imported_files/'+$scope.importedFile.id+"/process_file").success(() ->
      $scope.notices.push "Your file is being processed. You'll receive a system message when it is complete."
      $scope.showEmailCurrent=false
    ).error(() ->
      $scope.errors.push "There was an error processing the file. Please contact support."
    )

  $scope.downloadOriginal = () ->
    $.fileDownload '/imported_files/'+$scope.importedFile.id+'/download', (() ->
      console.log('download started')
    ), (() ->
      $scope.errors.push "There was an error downloading the file. Please contact support."
    )

  if($routeParams.fileId>0)
    $http.get('/imported_files/'+parseInt($routeParams.fileId)).success((data) ->
      $scope.importedFile = data
      $scope.emailCurrentSettings.to = $scope.importedFile.current_user.email
      if $scope.importedFile.last_processed && $scope.importedFile.last_processed.length>0
        $scope.searchResult.id = data.id
      else
        $scope.showPreviewBox = true
        $http.get('/imported_files/'+$scope.importedFile.id+'/preview').success((data) ->
          $scope.previewResults = data
        )
    )

  #
  # WATCHES
  #


  $scope.$watch 'searchResult.page', (newValue,oldValue) ->
    $location.path '/'+$scope.importedFile.id+'/'+newValue unless isNaN(newValue) || newValue==oldValue

  @
  ]

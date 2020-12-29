root = exports ? this
importedFileApp = angular.module('ImportedFileApp',['ngRoute','ChainComponents', 'LocalStorageModule']).config(['$routeProvider', ($routeProvider) ->
  $routeProvider.
    when('/:fileId',{templateUrl:'<%=asset_path("imported_file.html")%>',controller:'ImportedFileController'}).
    when('/:fileId/:page',{templateUrl:'<%=asset_path("imported_file.html")%>',controller:'ImportedFileController'})
])

importedFileApp.controller 'ImportedFileController', ['$scope', '$timeout', '$routeParams', '$http', '$location', 'chainSearchOperators', '$window', ($scope,$timeout,$routeParams,$http,$location,chainSearchOperators,$window) ->

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
    criterions.splice($.inArray(crit,criterions),1)

  $scope.showPreviewBox = false
  $scope.previewResults = []

  $scope.showEmailCurrent = false
  $scope.emailCurrentSettings = {to:'',subject:'[VFI Track] Current File Data',body:''}

  $scope.reloadWhenProcessed = () ->
    $http.get('/imported_files/'+parseInt($routeParams.fileId)+'.json').then((resp) ->
      importedFile = resp.data
      if importedFile.last_processed == ''
        $scope.importedFile = importedFile
        $timeout (-> $scope.reloadWhenProcessed()), 5000
      else
        $window.location.reload()
    )

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
    $http.post('/imported_files/'+$scope.importedFile.id+"/email_file.json",$scope.emailCurrentSettings).then(() ->
      $scope.notices.push "Your file has been scheduled and will be emailed soon."
    ,() ->
      $scope.errors.push "There was an error emailing this file. Please contact support."
    )

  $scope.updateSearchCriterions = () ->
    $scope.searchResult = {}
    $http.put('/imported_files/'+$scope.importedFile.id+'/update_search_criterions.json',JSON.stringify({imported_file:$scope.importedFile})).then(() ->
      $scope.searchResult = {
        id:$scope.importedFile.id
        saved:true
      } # Will trigger search reload, which in turn, will update this search result
    ,(resp) ->
      $scope.errors.push "Error saving results.  Please reload this page."
    )

  $scope.process = () ->
    $scope.showPreviewBox = false
    $http.post('/imported_files/'+$scope.importedFile.id+"/process_file.json").then(() ->
      $scope.showEmailCurrent=false
      $scope.notices.push "Your file is being processed. The screen will reload when it's finished."
      $scope.reloadWhenProcessed()
    ,(resp) ->
      $scope.errors.push "There was an error processing the file. Please contact support."
    )

  $scope.downloadOriginal = () ->
    $.fileDownload '/imported_files/'+$scope.importedFile.id+'/download', (() ->
      console.log('download started')
    ), (() ->
      $scope.errors.push "There was an error downloading the file. Please contact support."
    )

  $scope.showLog = (id) ->
    $window.location.href = "/file_import_results/" + id

  if($routeParams.fileId>0)
    $http.get('/imported_files/'+parseInt($routeParams.fileId)+'.json').then((resp) ->
      $scope.importedFile = resp.data
      $scope.emailCurrentSettings.to = $scope.importedFile.current_user.email
      if $scope.importedFile.total_rows && $scope.importedFile.total_rows > 0
        $scope.searchResult.id = resp.data.id
      else
        $scope.showPreviewBox = true
        $http.get('/imported_files/'+$scope.importedFile.id+'/preview.json').then((resp) ->
          if resp.data.error
            $scope.errors.push "There was an error loading the preview: " + resp.data.error
            $scope.showPreviewBox = false
          else
            $scope.previewResults = resp.data
        ,(resp) ->
          $scope.errors.push "There was an error processing this file. Please contact support."
        )
    )


  #
  # WATCHES
  #
  registrations = []

  registrations.push($scope.$watch 'searchResult.page', (newValue,oldValue, wScope) ->
    $location.path '/'+wScope.importedFile.id+'/'+newValue unless isNaN(newValue) || newValue==oldValue
  )

  #remove criterions that are deleted
  registrations.push($scope.$watch 'importedFile.search_criterions', ((n,o,wScope) ->
        return unless wScope.importedFile && wScope.importedFile.search_criterions && wScope.importedFile.search_criterions.length > 0
        for c in wScope.importedFile.search_criterions
          wScope.removeCriterion(c) if c.deleteMe
      ), true
  )

  $scope.$on('$destroy', () ->
    deregister() for deregister in registrations
    registrations = null
  )

  @
  ]

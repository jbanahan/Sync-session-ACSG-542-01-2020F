root = exports ? this
advSearchApp = angular.module('AdvancedSearchApp',['ChainComponents']).config(['$routeProvider', ($routeProvider) -> 
  $routeProvider.
    when('/:searchId/:page',{templateUrl:'/templates/advanced_search.html',controller:'AdvancedSearchCtrl'}).
    when('/:searchId',{templateUrl:'/templates/advanced_search.html',controller:'AdvancedSearchCtrl'}).
    when('/',{templateUrl:'/templates/advanced_search.html',controller:'AdvancedSearchCtrl'})
])

advSearchApp.controller 'AdvancedSearchCtrl',  ['$scope','$routeParams','$location','$http','chainSearchOperators',($scope,$routeParams,$location,$http,chainSearchOperators) ->
  
  #find object in array by mfid
  findByMfid = (ary,mfid) ->
    for m in ary
      return m if m.mfid==mfid
    return null
  
  #create new array with element moved up one position
  moveElementUp = (ary,idx) ->
    if idx <= 0
      r = []
      r.push o for o in ary
      return r
    x = ary.slice(0,idx-1) #get the items to the left
    x.push(ary[idx]) #add the element to be moved
    x = x.concat(ary.slice(idx-1)) #add the right side (still including the original item)
    x.splice(idx+1,1) #remove the original element
    return x

  #create a new array with element moved down one position
  moveElementDown = (ary,idx) ->
    return ary if idx == ary.length-1
    x = ary.slice(0,idx+2)
    x.push(ary[idx]) # 1,2,3,4,5 idx=2
    x = x.concat(ary.slice(idx+2))
    x.splice(idx,1)
    return x

  #ad the selected model field uids to the given array in the model
  addSelectionToModel = (modelArray, selectionArray) ->
    maxRank = if modelArray.length > 0 then modelArray[modelArray.length-1].rank else -1
    for mfid in selectionArray
      c = findByMfid $scope.searchSetup.model_fields, mfid
      sc = {mfid:c.mfid,label:c.label,rank:++maxRank}
      modelArray.push sc
    selectionArray.splice(0,selectionArray.length)
    resetAvailables()

  #remove the selected model field uids from the given array in the model
  removeSelectionFromModel = (modelArray, selectionArray) ->
    for mfid in selectionArray
      c = findByMfid modelArray, mfid
      if c
        idx = $.inArray c, modelArray
        modelArray.splice(idx,1)
    selectionArray.splice(0,selectionArray.length)
    resetAvailables()
    rankArray modelArray

  #move the selected items up one position in the array
  moveSelectionUp = (modelArray, selectionArray) ->
    for mfid in selectionArray
      c = findByMfid modelArray, mfid
      if c
        idx = $.inArray c, modelArray
        newArray = moveElementUp modelArray, idx
        #we can't replace the object for the target array so we need to clear
        #it and repopulate it with the values from the moveElementUp method
        #which returns a new array object
        modelArray.splice(0,modelArray.length)
        modelArray.push o for o in newArray
    rankArray modelArray

  #move the selected items down one position in the array
  moveSelectionDown = (modelArray, selectionArray) ->
    i = selectionArray.length-1
    while i>=0
      mfid = selectionArray[i]
      c = findByMfid modelArray, mfid
      if c
        idx = $.inArray c, modelArray
        newArray = moveElementDown modelArray, idx
        #we can't replace the object for the target array so we need to clear
        #it and repopulate it with the values from the moveElementDown method
        #which returns a new array object
        modelArray.splice(0,modelArray.length)
        modelArray.push o for o in newArray
      i--
    rankArray modelArray

  #reset the rank values for the objects in the array
  rankArray = (ary) ->
    rank = 0
    c.rank = rank++ for c in ary

  #reset the available columns list
  resetAvailables = () ->
    $scope.availableColumns = []
    $scope.availableSorts = []
    for mf in $scope.searchSetup.model_fields
      $scope.availableColumns.push mf unless findByMfid($scope.searchSetup.search_columns,mf.mfid)
      $scope.availableSorts.push mf unless findByMfid($scope.searchSetup.sort_criterions,mf.mfid)

  loadSearch = (id) ->
    $http.get('/advanced_search/'+id+'/setup').success((data,status,headers,config) ->
      $scope.searchSetup = data
      resetAvailables()
    ).error((data,status) ->
      if status == 404
        $scope.errors.push "This search with id "+id+" could not be found."
      else
        $scope.errors.push "An error occurred while loading this search setup. Please reload and try again."
    )

  $scope.searchId = parseInt $routeParams.searchId
  $scope.searchResult = {}
  pg = parseInt $routeParams.page
  pg = 1 if isNaN(pg) or pg<1
  $scope.page = pg

  if $scope.searchId
    loadSearch $scope.searchId
    $scope.searchResult.id = $scope.searchId
  else
    $http.get('/advanced_search/last_search_id').success((data,status,headers,config) ->
      $location.path '/'+data.id+'/'+$scope.page
    )

  $scope.operators = chainSearchOperators.ops
  $scope.columnsToRemove = []
  $scope.columnsToAdd = []
  $scope.availableColumns = []
  $scope.sortsToRemove = []
  $scope.sortsToAdd = []
  $scope.availableSorts = []
  $scope.criterionToAdd = null
  $scope.scheduleToEdit = null
  $scope.errors = []
  $scope.notices = []

  #give functionality
  $scope.giveUserId = null
  $scope.givePrompt = false

  $scope.give = (targetId) ->
    $scope.givePrompt = false
    $http.post('/search_setups/'+$scope.searchSetup.id+'/give',{'other_user_id':targetId}).success((data) ->
      $scope.notices.push "Report given to user."
    ).error((data) ->
      $scope.errors.push "Error giving this report, please try again."
    )


  #stateful view settings
  $scope.showSetup = false

  #save the search setup and reload the results on after save
  $scope.saveSetup = () ->
    $scope.searchResult = {}
    ss = $scope.searchSetup
    $scope.searchSetup = {}
    $http.put('/advanced_search/'+ss.id,JSON.stringify({search_setup:ss})).success(() ->
      loadSearch $scope.searchId
      $scope.searchResult.id = $scope.searchId
    ).error((data) ->
      $scope.error.push "An error occurred while saving this search."
    )
  
  #create a new setup and change location to first page
  $scope.newSetup = () ->
    $scope.searchResult = {}
    mt = $scope.searchSetup.module_type
    $scope.searchSetup = {}
    $http.post('/advanced_search',JSON.stringify({module_type:mt})).success((data) ->
      $location.path '/'+data.id+'/1'
    ).error((data) ->
      $scope.error.push "An error occurred while creating this search."
    )

  $scope.deletePrompt = false
  #delete current setup and change location to replacement setup
  $scope.deleteSetup = () ->
    $scope.searchResult = {}
    id = $scope.searchSetup.id
    $scope.searchSetup = {}
    $http.delete('/advanced_search/'+id).success((data) ->
      $location.path '/'+data.id+'/1'
    ).error((data) ->
      $scope.errors.push "An error occurred while deleting this search. Please reload and try again."
    )
  $scope.toggleSetup = () ->
    $scope.showSetup = !$scope.showSetup

  #put a schedule in edit mode
  $scope.editSchedule = (s) ->
    $scope.scheduleToEdit = s

  #create a new schedule and put it in edit mode
  $scope.addSchedule = () ->
    s = {email_addresses:$scope.searchSetup.user.email,download_format:'xls',run_hour:0,run_monday:true}
    $scope.searchSetup.search_schedules.push s
    $scope.editSchedule s

  $scope.removeSchedule = (s) ->
    schedules = $scope.searchSetup.search_schedules
    schedules.splice($.inArray(s, schedules),1)

  #add criterion to model
  $scope.addCriterion = (toAddId) ->
    toAdd = {value:''}
    mf = findByMfid $scope.searchSetup.model_fields, toAddId
    toAdd.mfid = mf.mfid
    toAdd.datatype = mf.datatype
    toAdd.label = mf.label
    toAdd.operator = $scope.operators[toAdd.datatype][0].operator
    $scope.searchSetup.search_criterions.push toAdd

  #remove criterion from model
  $scope.removeCriterion = (crit) ->
    criterions = $scope.searchSetup.search_criterions
    criterions.splice($.inArray(crit, criterions ),1)

  #add columns to the selected box
  $scope.addColumns = () ->
    addSelectionToModel $scope.searchSetup.search_columns, $scope.columnsToAdd

  #remove columns from selected box
  $scope.removeColumns = () ->
    removeSelectionFromModel($scope.searchSetup.search_columns, $scope.columnsToRemove)

  #add a blank column
  $scope.addBlank = () ->
    cols = $scope.searchSetup.search_columns
    maxRank = if cols.length > 0 then cols[cols.length-1].rank else -1
    cols.push {mfid:'_blank'+new Date().getTime(),label:'[blank]',rank:++maxRank}
    resetAvailables()

  $scope.moveColumnsUp = () ->
    moveSelectionUp $scope.searchSetup.search_columns, $scope.columnsToRemove

  $scope.moveColumnsDown = () ->
    moveSelectionDown $scope.searchSetup.search_columns, $scope.columnsToRemove

  #add sorts to the selected box
  $scope.addSorts = () ->
    addSelectionToModel $scope.searchSetup.sort_criterions, $scope.sortsToAdd

  #remove sorts from selected box
  $scope.removeSorts = () ->
    removeSelectionFromModel($scope.searchSetup.sort_criterions, $scope.sortsToRemove)

  #move sorts up in the list
  $scope.moveSortsUp = () ->
    moveSelectionUp $scope.searchSetup.sort_criterions, $scope.sortsToRemove

  #move sorts down in the list
  $scope.moveSortsDown = () ->
    moveSelectionDown $scope.searchSetup.sort_criterions, $scope.sortsToRemove

  #toggle sort order between ascending / descending
  $scope.toggleSort = () ->
    for s in $scope.sortsToRemove
      mf = findByMfid $scope.searchSetup.sort_criterions, s
      mf.descending = !mf.descending
  
  $scope.changeSearch = (newId) ->
    $location.path '/'+newId+'/1'

  #send background job to build excel
  $scope.backgroundDownload = () ->
    $scope.notices.push "Report is running in the background. You will receive a system message when it's done."
    $http.get('/advanced_search/'+$scope.searchSetup.id+"/download.json").error(() ->
      $scope.errors.push "Report download failed.  Please contact support"
    )
    
  #
  # WATCHES
  #
  registrations = []

  #change monitor for selected search
  registrations.push($scope.$watch 'searchId',(newValue,oldValue, watchScope) ->
    watchScope.changeSearch(newValue) unless isNaN(newValue) || newValue==oldValue
  )

  registrations.push($scope.$watch 'searchResult.page', (newValue, oldValue, watchScope) ->
    $location.path '/'+watchScope.searchId+'/'+newValue unless isNaN(newValue) || newValue==oldValue
  )


  #remove criterions that are deleted
  registrations.push($scope.$watch 'searchSetup.search_criterions', ((newValue, oldValue, watchScope) ->
      return unless watchScope.searchSetup && watchScope.searchSetup.search_criterions && watchScope.searchSetup.search_criterions.length > 0
      for c in watchScope.searchSetup.search_criterions
        watchScope.removeCriterion(c) if c.deleteMe
    ), true
  )

  $scope.$on('$destroy', () ->
    deregister() for deregister in registrations
    registrations = null
  )

  #
  #  VIEW FORMATTING UTILITIES BELOW HERE
  #

  #user friendly description of the schedule's timing
  $scope.scheduleTimingText = (s) ->
    h = parseInt s.run_hour
    o_clock = if h>12 then (h-12)+":00pm " else h+":00am"
    o_clock = 'midnight' if h==0
    o_clock = 'noon' if h==12
    r = "At "+o_clock+" on "
    if s.day_of_month > 0
      r += "day "+s.day_of_month+" of each month"
    else
      r += "Monday, " if s.run_monday
      r += "Tuesday, " if s.run_tuesday
      r += "Wednesday, " if s.run_wednesday
      r += "Thursday, " if s.run_thursday
      r += "Friday, " if s.run_friday
      r += "Saturday, " if s.run_saturday
      r += "Sunday" if s.run_sunday
    r = r.substr(0,r.length-2) if r.match /, $/
    return r

  $scope.descendingLabel = (bool) ->
    if bool then " (Z -> A)" else ""

  @
]

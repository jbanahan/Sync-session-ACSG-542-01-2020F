root = exports ? this
@app = angular.module('AdvancedSearchApp',['ngResource']).config(['$routeProvider', ($routeProvider) -> 
  $routeProvider.
    when('/:searchId/:page',{templateUrl:'/templates/advanced_search.html',controller:'AdvancedSearchCtrl'}).
    when('/:searchId',{templateUrl:'/templates/advanced_search.html',controller:'AdvancedSearchCtrl'}).
    when('/',{templateUrl:'/templates/advanced_search.html',controller:'AdvancedSearchCtrl'})
])

@app.controller 'AdvancedSearchCtrl',  ['$scope','$routeParams','$location','$http',($scope,$routeParams,$location,$http) ->
  
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
        idx = modelArray.indexOf c
        modelArray.splice(idx,1)
    selectionArray.splice(0,selectionArray.length)
    resetAvailables()
    rankArray modelArray

  #move the selected items up one position in the array
  moveSelectionUp = (modelArray, selectionArray) ->
    for mfid in selectionArray
      c = findByMfid modelArray, mfid
      if c
        idx = modelArray.indexOf c
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
        idx = modelArray.indexOf c
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

  #write cookie for current selection state
  writeSelectionCookie = () ->
    o = {rows:$scope.bulkSelected,all:$scope.allSelected}
    $.cookie("adv_srch_"+$scope.searchResult.id,JSON.stringify(o))

  #load selection state values from cookie
  readSelectionCookie = (searchId) ->
    v = $.cookie("adv_srch_"+searchId)
    if v
      o = $.parseJSON v
      $scope.bulkSelected = o.rows
      $scope.selectAll() if o.all
      for r in $scope.searchResult.rows
        r.bulk_selected = true if $scope.bulkSelected.indexOf(r.id)>=0

  loadResultPage = (searchId,page) ->
    $http.get('/advanced_search/'+searchId+'?page='+page).success((data,status,headers,config) ->
      $scope.searchResult = data
      readSelectionCookie data.id
    )
  loadSearch = (id) ->
    $http.get('/advanced_search/'+id+'/setup').success((data,status,headers,config) ->
      $scope.searchSetup = data
      resetAvailables()
    )

  $scope.searchId = parseInt $routeParams.searchId
  pg = parseInt $routeParams.page
  pg = 1 if isNaN(pg) or pg<1
  $scope.page = pg

  if $scope.searchId
    loadSearch $scope.searchId
    loadResultPage $scope.searchId, $scope.page
  else
    $http.get('/advanced_search/last_search_id').success((data,status,headers,config) ->
      $location.path '/'+data.id+'/'+$scope.page
    )

  $scope.columnsToRemove = []
  $scope.columnsToAdd = []
  $scope.availableColumns = []
  $scope.sortsToRemove = []
  $scope.sortsToAdd = []
  $scope.availableSorts = []
  $scope.criterionToAdd = null
  $scope.scheduleToEdit = null

  #stateful view settings
  $scope.showSetup = false

  #save the search setup and reload the results on after save
  $scope.saveSetup = () ->
    $scope.searchResult = {}
    $scope.searchSetup = {}
    $http.put('/advanced_search/'+$scope.searchSetup.id,JSON.stringify({search_setup:$scope.searchSetup})).success(() ->
      loadSearch $scope.searchId
      loadResultPage $scope.searchId, 1
    )
  
  #create a new setup and change location to first page
  $scope.newSetup = () ->
    $scope.searchResult = {}
    mt = $scope.searchSetup.module_type
    $scope.searchSetup = {}
    $http.post('/advanced_search',JSON.stringify({module_type:mt})).success((data) ->
      $location.path '/'+data.id+'/1'
    )

  $scope.deletePrompt = false
  #delete current setup and change location to replacement setup
  $scope.deleteSetup = () ->
    $scope.searchResult = {}
    id = $scope.searchSetup.id
    $scope.searchSetup = {}
    $http.delete('/advanced_search/'+id).success((data) ->
      $location.path '/'+data.id+'/1'
    )
  #
  # Bulk action handling
  #

  #active list of selected bulk actions
  $scope.bulkSelected = []
  $scope.allSelected = false
  $scope.selectPageCheck = false

  #clear selection
  $scope.selectNone = () ->
    $scope.bulkSelected = []
    $scope.allSelected = false
    r.bulk_selected = false for r in $scope.searchResult.rows

  $scope.selectAll = () ->
    $scope.allSelected = true
    r.bulk_selected = true for r in $scope.searchResult.rows

  $scope.selectPage = () ->
    r.bulk_selected = true for r in $scope.searchResult.rows

  #run a bulk action
  $scope.executeBulkAction = (bulkAction) ->
    selectedItems = $scope.bulkSelected
    sId = (if $scope.allSelected then $scope.searchResult.search_run_id else null)
    cb = null
    cb = eval(bulkAction.callback) if bulkAction.callback
    if cb
      BulkActions.submitBulkAction selectedItems, sId, bulkAction.path, 'post', cb
    else
      BulkActions.submitBulkAction selectedItems, sId, bulkAction.path, 'post'

  #
  # End bulk action handling
  #

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
    schedules.splice(schedules.indexOf(s),1)

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
    criterions.splice(criterions.indexOf(crit),1)

  #add columns to the selected box
  $scope.addColumns = () ->
    addSelectionToModel $scope.searchSetup.search_columns, $scope.columnsToAdd

  #remove columns from selected box
  $scope.removeColumns = () ->
    removeSelectionFromModel($scope.searchSetup.search_columns,$scope.columnsToRemove)

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
    removeSelectionFromModel($scope.searchSetup.sort_criterions,$scope.sortsToRemove)

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
    
  #
  # WATCHES
  #

  #change monitor for selected search
  $scope.$watch 'searchId',(newValue,oldValue) ->
    $scope.changeSearch(newValue) unless isNaN(newValue) || newValue==oldValue

  $scope.$watch 'searchResult.page', (newValue,oldValue) ->
    $location.path '/'+$scope.searchId+'/'+newValue unless isNaN(newValue) || newValue==oldValue

  $scope.$watch 'searchResult', ((newValue,oldValue) ->
    if newValue && newValue.rows
      for r in newValue.rows
        if r.bulk_selected
          $scope.bulkSelected.push(r.id) unless $scope.bulkSelected.indexOf(r.id)>=0
        else
          idx = $scope.bulkSelected.indexOf(r.id)
          $scope.bulkSelected.splice(idx,1) if idx>=0
          $scope.allSelected = false
    $scope.selectPageCheck = false
    ), true #true means "deep search"

  $scope.$watch 'bulkSelected', ((newValue,oldValue) ->
    writeSelectionCookie() unless newValue==oldValue
  ), true

  $scope.$watch 'allSelected', (newValue,oldValue) ->
    writeSelectionCookie() unless newValue==oldValue

  #
  #  VIEW FORMATTING UTILITIES BELOW HERE
  #

  #return true if the given row's id is different than the previous rows id
  $scope.newObjectRow = (idx) ->
    return true if idx==0
    myRowId = $scope.searchResult.rows[idx].id
    lastRowId = $scope.searchResult.rows[idx-1].id
    return myRowId!=lastRowId && idx>0

  #return the classes that should be applied to a result row based on it's position and whether it's the first instance of a new row key
  $scope.classesForRow = (idx) ->
    return ['hover'] if idx==0
    r = ['hover']
    r.push 'search_row_break' if $scope.newObjectRow(idx)
    r

  #return array of valid page numbers for the current search result
  $scope.pageNumberArray = () ->
    if $scope.searchResult
      [1..$scope.searchResult.total_pages]
    else
      [1]

  #user friendly description of the schedule's timing
  $scope.scheduleTimingText = (s) ->
    h = parseInt s.run_hour
    o_clock = if h>12 then (h-12)+":00am " else h+":00pm"
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

  #get the search operator for given datatype
  $scope.operators =
    date: [
      {operator:'eq',label:'Equals'}
      {operator:'nq',label:'Not Equal To'}
      {operator:'gt',label:'After'}
      {operator:'lt',label:'Before'}
      {operator:'bda',label:'Before _ Days Ago'}
      {operator:'ada',label:'After _ Days Ago'}
      {operator:'bdf',label:'Before _ Days From Now'}
      {operator:'adf',label:'After _ Days From Now'}
      {operator:'pm',label:'Previous _ Months'}
      {operator:'null',label:'Is Empty'}
      {operator:'notnull',label:'Is Not Empty'}
      ]
    datetime: [
      {operator:'eq',label:'Equals'}
      {operator:'nq',label:'Not Equal To'}
      {operator:'gt',label:'After'}
      {operator:'lt',label:'Before'}
      {operator:'bda',label:'Before _ Days Ago'}
      {operator:'ada',label:'After _ Days Ago'}
      {operator:'bdf',label:'Before _ Days From Now'}
      {operator:'adf',label:'After _ Days From Now'}
      {operator:'pm',label:'Previous _ Months'}
      {operator:'null',label:'Is Empty'}
      {operator:'notnull',label:'Is Not Empty'}
      ]
    integer: [
      {operator:'eq',label:'Equals'}
      {operator:'nq',label:'Not Equal To'}
      {operator:'gt',label:'Greater Than'}
      {operator:'lt',label:'Less Than'}
      {operator:'sw',label:'Starts With'}
      {operator:'ew',label:'Ends With'}
      {operator:'co',label:'Contains'}
      {operator:'in',label:'One Of'}
      {operator:'null',label:'Is Empty'}
      {operator:'notnull',label:'Is Not Empty'}
      ]
    decimal: [
      {operator:'eq',label:'Equals'}
      {operator:'nq',label:'Not Equal To'}
      {operator:'gt',label:'Greater Than'}
      {operator:'lt',label:'Less Than'}
      {operator:'sw',label:'Starts With'}
      {operator:'ew',label:'Ends With'}
      {operator:'co',label:'Contains'}
      {operator:'in',label:'One Of'}
      {operator:'null',label:'Is Empty'}
      {operator:'notnull',label:'Is Not Empty'}
      ]
    fixnum: [
      {operator:'eq',label:'Equals'}
      {operator:'nq',label:'Not Equal To'}
      {operator:'gt',label:'Greater Than'}
      {operator:'lt',label:'Less Than'}
      {operator:'sw',label:'Starts With'}
      {operator:'ew',label:'Ends With'}
      {operator:'co',label:'Contains'}
      {operator:'in',label:'One Of'}
      {operator:'null',label:'Is Empty'}
      {operator:'notnull',label:'Is Not Empty'}
      ]
    string: [
      {operator:'eq',label:'Equals'}
      {operator:'nq',label:'Not Equal To'}
      {operator:'sw',label:'Starts With'}
      {operator:'ew',label:'Ends With'}
      {operator:'co',label:'Contains'}
      {operator:'nc',label:"Doesn't Contain"}
      {operator:'in',label:'One Of'}
      {operator:'null',label:'Is Empty'}
      {operator:'notnull',label:'Is Not Empty'}
      ]
    text: [
      {operator:'eq',label:'Equals'}
      {operator:'nq',label:'Not Equal To'}
      {operator:'sw',label:'Starts With'}
      {operator:'ew',label:'Ends With'}
      {operator:'co',label:'Contains'}
      {operator:'nc',label:"Doesn't Contain"}
      {operator:'in',label:'One Of'}
      {operator:'null',label:'Is Empty'}
      {operator:'notnull',label:'Is Not Empty'}
      ]
    boolean: [
      {operator:'notnull',label:'Yes'}
      {operator:'null',label:'No'}
      ]
  @
]

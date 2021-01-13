root = exports ? this
advSearchApp = angular.module('AdvancedSearchApp',['ngRoute','ChainComponents','LocalStorageModule']).config(['$routeProvider', ($routeProvider) ->
  $routeProvider.
    when('/:searchId/:page',{templateUrl:'<%=asset_path("advanced_search.html")%>',controller:'AdvancedSearchCtrl'}).
    when('/:searchId',{templateUrl:'<%=asset_path("advanced_search.html")%>',controller:'AdvancedSearchCtrl'}).
    when('/',{templateUrl:'<%=asset_path("advanced_search.html")%>',controller:'AdvancedSearchCtrl'})
])
advSearchApp.config ['$httpProvider', ($httpProvider) ->
  $httpProvider.defaults.headers.common['Accept'] = 'application/json'
]

advSearchApp.controller 'AdvancedSearchCtrl',  ['$scope','$routeParams','$location','$http','chainSearchOperators','$timeout', '$q', '$window', ($scope,$routeParams,$location,$http,chainSearchOperators,$timeout,$q,$window) ->

  $scope.tour = new Tour(
    storage: false
    orphan: true
    onStart: () ->
      unless ($('#search_setup_controls').hasClass('ng-hide'))
        $scope.toggleSetup()
    onEnd: () ->
      unless ($('#search_setup_controls').hasClass('ng-hide'))
        $scope.toggleSetup()
    template: "<div class='popover tour popover_large_image'>
        <div class='arrow'></div>
        <h3 class='popover-header'></h3>
        <div class='popover-body'></div>
        <div class='popover-navigation'>
          <hr />
          <div class='btn-group'>
            <button class='btn btn-sm btn-secondary' data-role='prev'><i class='fa fa-caret-left' aria-hidden='true'></i> Prev</button>
            <button id='tour_nxt_btn' class='btn btn-sm' data-role='next'>Next <i class='fa fa-caret-right' style='color: gold' aria-hidden='true'></i></button>
          </div>
          <button class='btn btn-sm btn-secondary' data-role='end'>End Tour</button>
        </div>
      </div>"
    steps: [
      {
        title: 'Welcome to the Advanced Search Tour'
        content: "You can use the arrow keys to move back and forth through the tour."
        template: "<div class='popover tour'>
          <div class='arrow'></div>
          <h3 class='popover-header'></h3>
          <div class='popover-body'></div>
          <div class='popover-navigation'>
            <hr />
            <div class='btn-group'>
              <button class='btn btn-sm btn-secondary' data-role='prev'><i class='fa fa-caret-left' aria-hidden='true'></i> Prev</button>
              <button id='tour_nxt_btn' class='btn btn-sm' data-role='next'>Next <i class='fa fa-caret-right' style='color: gold' aria-hidden='true'></i></button>
            </div>
            <button class='btn btn-sm btn-secondary' data-role='end'>End Tour</button>
          </div>
        </div>"
      }
      {
        title: "Selecting your Search"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Your previously saved searches will appear in this dropdown menu.
          Results from the most recently run search appear below the dropdown menu.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 2.jpg") %>
          </div></div>"
      }
      {
        title: "Setup a search"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>After selecting a saved search from the dropdown, click the
          Gears button to create a new search or modify a previously created search.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 3.jpg") %>
          </div></div>"
      }
      {
        title: "Naming your search"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>You may name your searches whatever you'd like to distinguish between them.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 4.jpg") %>
          </div></div>"
      }
      {
        title: "Download File Format"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Select the format you'd like for the download.
          In general XLSX format is preferred, however older XLS format and CSV
          (comma delimited) is available.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 5.jpg") %>
          </div></div>"
      }
      {
        title: "Include Links in Download"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>If you decide to download your search results, this checkbox will add
          weblinks to each record in Maersk Navigator from the search results.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 6.jpg") %>
          </div></div>"
      }
      {
        title: "Hide Time"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Only want to see dates in a datetime field? Check this box to hide the
          time from view.
          Downloaded results will exclude the time as well.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 7.jpg") %>
          </div></div>"
      }
      {
        title: "Selecting and filtering columns"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Each Maersk Navigator module has many fields available in Advanced Search so it is recommended to use the filter box below the available fields to find the field you are looking for.
          Just start typing the field name and the Available Fields box will filter the view for you.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 8.jpg") %>
            </div></div>"
      }
      {
        title: "Adding Fields to Your Search"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Fields selected here will be added as a column to your search results.
          Highlight the field (or more than one field by holding down Ctrl while clicking
          each field name) and then click Add.<br /><br />You can also easily add a custom
          column with a hardcoded value. Click the Custom Column button, give your column a
          name, and provide an optional column value. The column value, if provided, will
          be repeated on every row in the report. The column value can be left blank.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 9.jpg") %>
          </div></div>"
      }
      {
        title: "Change Column Order"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Select the field you want to move, then click Up or Down to move it.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 10.jpg") %>
          </div></div>"
      }
      {
        title: "Remove a Column"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Select the field you want to remove, then click Remove to remove it
          from your Included columns.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 11.jpg") %>
          </div></div>"
      }
      {
        title: "Sorting Data"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>The data can be sorted by nearly any field or combination of
          fields of data selected. Similar to the column selection you can filter
          through them with the search below the Available Sorts.
          <br /><br />
          You can sort a search by a field even if it is not included as a
          column in the results.
          <br /><br />
          You can switch between ascending and descending sort for each sort
          criteria by clicking the Change Order button.
          <br /><br />
          *Note that you have to select a parameter below before a sort can be
          included.
          </h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 12.jpg") %>
          </div></div>"
      }
      {
        title: "Selecting parameters"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>To add a parameter, select one from the dropdown menu next to 'Add New'.
          You can type the first few characters of the field name for faster selection.
          There is no limit to the number of parameters you can add.</h5></div>
          <div class='col-sm-9 col-sx-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 13.jpg") %>
          </div></div>"
      }
      {
        title: "Selecting comparator"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>After a parameter is selected choose a comparator from the dropdown
          and add a value to be compared to in the input field.
          <br /><br />
          You can include blank values in the results for each parameter by
          checking the Include Empty box.
          <br /><br />
          *Note that report comparator definitions are available in the user
          manual section.
          </h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 14.jpg") %>
          </div></div>"
      }
      {
        title: "Scheduling Search Results"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>You can generate the results of your search on a schedule of your
          choosing.
          The results will then be sent to email addresses that you specify.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 15.jpg") %>
          </div></div>"
      }
      {
        title: "Setting up a schedule"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Specify the email address(es) you would like to receive your search
          results. Multiple email addresses can be added by separating them with a
          comma.
          <br /><br />
          Check the Send if Empty box if you would like to receive the scheduled
          results even if there are no results from the search.
          <br /><br />
          Select your schedule interval. You can select a specific day of the month
          for a monthly report, select a day of the week for a weekly report, or select each day of the week for a daily report. Multiple schedules can be set up as needed.
          <br /><br />
          Click Done when you have finished creating your schedule.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 16.jpg") %>
          </div></div>"
      }
      {
        title: "Save Your Search"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Ensure that your changes aren't lost by clicking save!
          This also runs the search and the results will display below.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 17.jpg") %>
          </div></div>"
      }
      {
        title: "Starting from scratch"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Click here to create a new search from scratch.
          This will not save changes you've made above!</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 18.jpg") %>
          </div></div>"
      }
      {
        title: "Duplication"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>If you'd like to start a new search using similar columns and/or
          parameters, then click here to make a copy of an existing search.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 19.jpg") %>
          </div></div>"
      }
      {
        title: "Sharing Search Results"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>If you would like to share the search you've created then click
          here and select another user from the dropdown.
          The user will receive a copy of the search you created and their changes
          will not affect your version.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 20.jpg") %>
          </div></div>"
      }
      {
        title: "Download your Search Results"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Results are limited to 1000 lines on screen, but up to 10,000 lines
          can be downloaded as an XLSX, XLS, or CSV file by clicking this button.
          The search will run in the background and you will receive a system
          message when it is ready to be downloaded.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 21.jpg") %>
          </div></div>"
      }
      {
        title: "Email your Search Results"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>Search results can be emailed to any recipient, even those without
          Maersk Navigator accounts.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 22.jpg") %>
          </div></div>"
      }
      {
        title: "Random Audit Generator"
        content: "<div class='row'><div class='col-md-3 col-12'>
          <h5>With the Random Audit Generator, Maersk Navigator will randomly select
          a user-defined percentage of your search results and present them for an
          audit. After saving your search, click the random audit button to set your
          options and generate the results. You will receive a system message when
          the results are ready for download. You can return to the Random Audit
          screen from any search screen to download previous results.</h5>
          </div><div class='col-sm-9 col-12'>
            <%= ActionController::Base.helpers.escape_javascript image_pack_tag("tour_images/advanced search tour 23.jpg") %>
          </div></div>"
      }
      {
        title: "Thank You for Using Maersk Navigator"
        content: "This completes the Maersk Navigator Advanced Search tour."
        template: "<div class='popover tour'>
          <div class='arrow'></div>
          <h3 class='popover-header'></h3>
          <div class='popover-body'></div>
          <div class='popover-navigation'>
            <div class='btn-group'>
              <button class='btn btn-sm btn-secondary' data-role='prev'><i class='fa fa-caret-left' aria-hidden='true'></i> Prev</button>
              <button id='tour_nxt_btn' class='btn btn-sm' data-role='next'>Next <i class='fa fa-caret-right' style='color: gold' aria-hidden='true'></i></button>
            </div>
            <button class='btn btn-sm btn-secondary' data-role='end'>Finish Tour</button>
          </div>
        </div>"
      }
    ]).init()

  $scope.showTour = () ->
    $scope.tour.restart()

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
    # Returns null if the element is already at the end of the array
    return null if idx >= ary.length-1
    x = ary.slice(0,idx+2)
    x.push(ary[idx]) # 1,2,3,4,5 idx=2
    x = x.concat(ary.slice(idx+2))
    x.splice(idx,1)
    return x

  #add the selected model field uids to the given array in the model
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
        if newArray
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
    $scope.constantField = {}
    for mf in $scope.searchSetup.model_fields
      $scope.availableColumns.push mf unless findByMfid($scope.searchSetup.search_columns,mf.mfid)
      $scope.availableSorts.push mf unless findByMfid($scope.searchSetup.sort_criterions,mf.mfid)

  loadSearch = (id) ->
    successCallback = (resp) ->
      $window.document.title = resp.data.title
      $scope.searchSetup = resp.data
      BulkActions.setCoreModule(resp.data.module_type)
      resetAvailables()

    errorCallback = (resp) ->
      if resp.status == 404
        $scope.errors.push "This search with id "+id+" could not be found."
      else
        $scope.errors.push "An error occurred while loading this search setup. Please reload and try again."

    $http.get('/advanced_search/'+id+'/setup.json').then(successCallback,errorCallback)

  $scope.searchId = parseInt $routeParams.searchId
  $scope.searchWrapper = {searchResult:{}, canceller: {cancel: $q.defer(), cancelled: $q.defer()} , loading: false}
  pg = parseInt $routeParams.page
  pg = 1 if isNaN(pg) or pg<1
  $scope.page = pg

  if $scope.searchId
    loadSearch $scope.searchId
    $scope.searchWrapper.searchResult.id = $scope.searchId
  else
    $http.get('/advanced_search/last_search_id.json').then((resp) ->
      $location.path '/'+resp.data.id+'/'+$scope.page
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

  #email and status panels
  $scope.sendEmail = (mailFields) ->
    successCallback = (resp) ->
      $('#email-modal').modal 'hide'
      $scope.clearPanels
      $scope.setSuccessPanel "Email sent"
      window.scrollTo(0,0)

    errorCallback = (resp) ->
      if resp.error
        $scope.setErrorPanel resp.error
      else
        $scope.setErrorPanel 'Server temporarily unavailable. Please try again later.'

    $http.post('/advanced_search/'+$scope.searchSetup.id+'/send_email',{'mail_fields':mailFields}).then(successCallback,errorCallback)

  $scope.setErrorPanel = (message) ->
    panel = Chain.makeErrorPanel(message, false)
    $scope.clearPanels()
    $('#email-modal-container').prepend(panel)
    true

  $scope.setSuccessPanel = (message) ->
    panel = Chain.makeSuccessPanel(message, true)
    $scope.clearPanels()
    $('#advanced_search_wrapper').prepend(panel)
    true

  $scope.clearPanels = () ->
    $('.card-success').remove()
    $('.card-danger').remove()
    true

  #give functionality
  $scope.giveUserId = null
  $scope.givePrompt = false

  $scope.give = (targetId) ->
    $scope.givePrompt = false
    $scope.giveUserId = null
    successCallback = (resp) ->
      if resp.data.given_to
        $scope.notices.push "Report given to " + resp.data.given_to + "."
      else
        $scope.notices.push "Report given to user."

    errorCallback = (resp) ->
      $scope.errors.push "Error giving this report, please try again."

    $http.post('/search_setups/'+$scope.searchSetup.id+'/give.json',{'other_user_id':targetId}).then(successCallback,errorCallback)

  $scope.copyReportName = null
  $scope.copyPrompt = false

  $scope.copy = (copyName) ->
    $scope.copyPrompt = false
    $scope.copyReportName = null
    successCallback = (resp) ->
      $scope.notices.push "A copy of this report has been created as " + resp.data.name + "."
      $location.path '/'+resp.data.id+'/1'

    errorCallback = (resp) ->
      $scope.copyPrompt = true
      if resp.error
        $scope.errors.push resp.error
      else
        $scope.errors.push "Error copying this report, please try again."

    $http.post('/search_setups/'+$scope.searchSetup.id+'/copy.json',{'new_name':copyName}).then(successCallback,errorCallback)

  $scope.makeTemplate = (ss) ->
    successCallback = (resp) ->
      $scope.notices.push "Template created successfully."

    errorCallback = (resp) ->
      if resp.error
        $scope.errors.push resp.error
      else
        $scope.errors.push "Error creating template."

    $http.post('/api/v1/admin/search_setups/'+ss.id+'/create_template.json',{}).then(successCallback,errorCallback)

  #stateful view settings
  $scope.showSetup = false

  $scope.showEmailModal = () ->
    $scope.mailFields = {'to': $scope.searchSetup.user.email}
    $('#email-modal').modal 'show'
    true

  $scope.handleSearchOverride = (scope, callback) ->
    if scope.searchWrapper.loading && scope.errors.length == 0
      canceller = scope.searchWrapper.canceller
      canceller.cancel.resolve('SearchOverride')
      canceller.cancelled.promise.then ->
        # reset promises
        canceller.cancel = $q.defer()
        canceller.cancelled = $q.defer()
        callback()
    else
      scope.searchWrapper.loading = true
      callback()
    null

  $scope.unlockSearch = () ->
    $scope.searchSetup.locked = false

  #save the search setup and reload the results on after save
  $scope.saveSetup = (locked) ->
    $scope.handleSearchOverride($scope, () ->
      $scope.toggleSetup()
      $scope.searchWrapper.searchResult = {}
      ss = $scope.searchSetup
      ss.locked = locked
      $scope.searchSetup = {}

      if ss.search_criterions.length == 0
        ss.sort_criterions = []
        ss.search_schedules = []

      ss.search_schedules = (sched for sched in ss.search_schedules when !$scope.emailTooLong(sched))

      successCallback = () ->
        # Unless we're already on the first page, change to it.
        if $scope.page != 1
          $location.path '/'+ss.id+'/1'
        else
          # The searchResult.saved attribute lets the components watcher know that
          # the user saved the scope (.ie this isn't an initial load)
          $scope.searchWrapper.searchResult = {
            id: ss.id
            saved: true
          }
          loadSearch parseInt $routeParams.searchId

      errorCallback = (data) ->
        $scope.errors.push "An error occurred while saving this search."

      $http.put('/advanced_search/'+ss.id+'.json',JSON.stringify({search_setup:ss})).then(successCallback,errorCallback)
    )

  $scope.changeSearch = (newId) ->
    $scope.handleSearchOverride($scope, () ->
      $location.path('/'+newId+'/1')
    )

  #create a new setup and change location to first page
  $scope.newSetup = () ->
    $scope.searchWrapper.searchResult = {}
    mt = $scope.searchSetup.module_type
    $scope.searchSetup = {}

    successCallback = (resp) ->
      $location.path '/'+resp.data.id+'/1'

    errorCallback = (resp) ->
      $scope.error.push "An error occurred while creating this search."

    $http.post('/advanced_search.json',JSON.stringify({module_type:mt})).then(successCallback,errorCallback)

  $scope.deletePrompt = false
  #delete current setup and change location to replacement setup
  $scope.deleteSetup = () ->
    $scope.searchWrapper.searchResult = {}
    id = $scope.searchSetup.id
    $scope.searchSetup = {}
    successCallback = (resp) ->
      $location.path '/'+resp.data.id+'/1'

    errorCallback = (resp) ->
      $scope.errors.push "An error occurred while deleting this search. Please reload and try again."

    $http.delete('/advanced_search/'+id+'.json').then(successCallback, errorCallback)

  $scope.toggleSetup = () ->
    $scope.showSetup = !$scope.showSetup
    $timeout ->
      $('#search-setup-name-box').focus()
    null #can't return jquery object

  #put a schedule in edit mode
  $scope.editSchedule = (s) ->
    $scope.scheduleToEdit = s

  #create a new schedule and put it in edit mode
  $scope.addSchedule = () ->
    s = {email_addresses:$scope.searchSetup.user.email,download_format:'xls',send_if_empty:true,run_hour:0,run_monday:true,date_format:$scope.searchSetup.date_format}
    $scope.searchSetup.search_schedules.push s
    $scope.editSchedule s

  $scope.removeSchedule = (s) ->
    schedules = $scope.searchSetup.search_schedules
    schedules.splice($.inArray(s, schedules),1)

  $scope.closeSchedule = (s) ->
    if s.email_addresses != ""
      $http.get('/api/v1/emails/validate_email_list.json', {params:{email: s.email_addresses}}).then (resp) ->
        if resp.data.valid
          $('#invalid-email-flag').hide()
          $scope.scheduleToEdit = null
        else
          $('#invalid-email-flag').show()
          true
    else
      $scope.scheduleToEdit = null

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

  # show constant-field inputs
  $scope.toggleConstantField = () ->
    $scope.displayConstantField = !$scope.displayConstantField

  $scope.addConstantField = () ->
    $scope.addAnyConstantField $scope.constantField.name, $scope.constantField.value

  $scope.addAnyConstantField = (fieldName, fieldValue) ->
    cols = $scope.searchSetup.search_columns
    maxRank = if cols.length > 0 then cols[cols.length-1].rank else -1
    cols.push {mfid:'_const'+new Date().getTime(),label: fieldName, constant_field_value: fieldValue, rank:++maxRank}
    $scope.displayConstantField = false
    resetAvailables()

  $scope.isConstantUid = (uid) ->
    /^_const/.test uid

  $scope.columnLabel = (searchColumn) ->
    if $scope.isConstantUid searchColumn.mfid
      "*" + searchColumn.label
    else
      searchColumn.label

  $scope.hasConstantColumns = () ->
    if $scope.searchSetup
      columns = $scope.searchSetup.search_columns || []
      columns.some (col) ->
        $scope.isConstantUid col.mfid

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

  #send background job to build excel
  $scope.backgroundDownload = () ->

    successCallback = (resp) ->
      $scope.notices.push "Report is running in the background. You will receive a system message when it's done."

    errorCallback = (resp) ->
      if resp.data.errors
        $scope.errors.push error for error in resp.data.errors
      else
        $scope.errors.push "Report download failed.  Please contact support"

    $http.get('/advanced_search/'+$scope.searchSetup.id+"/download.json").then(successCallback,errorCallback)

  $scope.foregroundDownload = () ->
    downloadFormat = $scope.searchSetup.download_format
    # Default to xlsx if format is blank
    downloadFormat = "xlsx" if !downloadFormat
    $window.location.href = "advanced_search/#{$scope.searchSetup.id}/download.#{downloadFormat}"

  $scope.emailTooLong = (sched) ->
    sched.email_addresses.length > 255 if sched

  #
  # WATCHES
  #
  registrations = []

  registrations.push($scope.$watch 'searchWrapper.searchResult.page', (newValue, oldValue, watchScope) ->
    $location.path '/'+watchScope.searchId+'/'+newValue unless isNaN(newValue) || newValue==oldValue
  )


  #remove criterions that are deleted
  registrations.push($scope.$watch 'searchSetup.search_criterions', ((newValue, oldValue, watchScope) ->
      return unless watchScope.searchSetup && watchScope.searchSetup.search_criterions && watchScope.searchSetup.search_criterions.length > 0
      for c in watchScope.searchSetup.search_criterions
        watchScope.removeCriterion(c) if c && c.deleteMe  # Not sure why, but I've seen console errors due to c being null here.
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
    r = o_clock+" on "
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

  $scope.scheduleProtocol = (s) ->
    protocol = s?.protocol
    if protocol && protocol.length > 0 then protocol.toUpperCase() else "FTP"

  $scope.descendingLabel = (bool) ->
    if bool then " (Z -> A)" else ""

  @
]
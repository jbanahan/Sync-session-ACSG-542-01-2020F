@components = angular.module 'ChainComponents', []

# moves the transcluded content into the action bar
# each instance must have a unique ID attribute
@components.directive 'chainActionBarItem', [() ->
  {
    transclude:true
    template:"<div class='chainActionBarWrap' ng-transclude></div>"
    link: (scope,el,attrs) ->
      d = el.find('div.chainActionBarWrap')
      d.attr('action-bar-item-id',el.attr('id'))
      existingEl = $('div.action_container div.chainActionBarWrap[action-bar-item-id="'+el.attr('id')+'"]')
      existingEl.remove()
      $("div.action_container").append(d)
      d.find('button').button()
    }
]

# creates a modal dialog box with a link based on the title attributes and transcludes the content into the body of the dialog.  There will be an "OK" button to close the dialog.
@components.directive 'chainMessageBox', [() ->
  {
    scope: {
      title:'=title'
      asButton:'=asButton'
    }
    transclude:true
    template:"<div class='dialog_content_wrap' ng-transclude></div>"
    link: (scope,el,attrs) ->
      if scope.asButton
        el.prepend("<button class='chainMessageBoxLauncher'>"+scope.title+"</button>")
        el.find('button.chainMessageBoxLauncher').button()
      else
        el.prepend("<a class='action_link chainMessageBoxLauncher'>"+scope.title+'</a>')
      d = el.find("div.dialog_content_wrap")
      d.dialog({
        modal:true
        autoOpen:false
        buttons:{
          "OK": () ->
            $(@).dialog('close')
          }
        }
      )
      el.find(".chainMessageBoxLauncher").click(() ->
        d.dialog('open')
      )
    }
]

# shows the user a drop down to select a user and sets the 
# selected user id into the passed in object
# <div user-list="myUserIdVariable"></div>
@components.directive 'chainUserList', ['$parse','$http',($parse,$http) ->
  {
    scope: {
      chainUserList:"="
    },
    template:"<select ng-model='chainUserList' ng-options='u.id as u.full_name group by u.company_name for u in users'></select>",
    link: (scope,el,attrs) ->
      $http.get('/users.json').success((data) ->
        scope.users = []
        for c in data
          cName = c.company.name
          for u in c.company.users
            u.company_name = cName
            scope.users.push u
      )
    }
]
@components.directive 'chainMessages', [() ->
  {
    scope: {
      errors:"=",
      notices:"="
    }
    templateUrl:'/templates/chain_messages.html'
    }
]
@components.directive 'chainDatePicker', [() ->
  {
    scope: {
      chainDatePicker:"="
    }
    template:"<input type='text' disabled='disabled' />",
    link: (scope,el,attrs) ->
      $(el).find('input').datepicker({
        buttonText:'Select Date',
        dateFormat:'yy-mm-dd',
        onSelect:(text,dp) ->
          scope.$apply () ->
            scope.chainDatePicker = text
        showOn: 'button'
        }
      )
      #add watch to update
      scope.$watch 'chainDatePicker', (newVal) ->
        $(el).find('input').val(newVal)
  }
]
@components.directive 'chainSearchCriterion', ['$compile','chainSearchOperators',($compile,chainSearchOperators) ->
  {
    scope: {crit:"=chainSearchCriterion"},
    templateUrl:"/templates/chain_search_criterion.html",
    controller: ['$scope',($scope) ->
      $scope.operators = chainSearchOperators.ops

      # parent controller needs to $watch for deleteMe and do the actual work of removing the object!
      $scope.remove = (crit) ->
        crit.deleteMe = true

      $scope.updateValueHtml = () ->
        
    ],
    link: (scope, el, attrs) ->
      renderTextInput = (opr) ->
        switch opr
          when "in", "notin"
            return "<textarea ng-model='crit.value' />"
          when "null", "notnull"
            return ""

        return "<input type='text' ng-model='crit.value' />"

      render = () ->
        dateStepper = false #true means apply jStepper to a relative date field
        v_str = "<input type='text' ng-model='crit.value' />"
        switch scope.crit.datatype
          when "string", "integer", "fixnum", "decimal"
            v_str = renderTextInput scope.crit.operator
          when "date", "datetime"
            if chainSearchOperators.isRelative scope.crit.datatype, scope.crit.operator
              v_str = "<input type='text' ng-model='crit.value' />"
              dateStepper = true
            else
              v_str = "<div style='display:inline;' chain-date-picker='crit.value'></div>"
          when "boolean"
            v_str = ""
          when "text"
            v_str = "<textarea ng-model='crit.value' />"
        v = $compile(v_str)(scope)
        va = $(el).find(".value_area")
        va.html(v)
        switch scope.crit.datatype
          when "integer", "fixnum"
            va.find('input').jStepper({allowDecimals:false})
          when "decimal"
            va.find('input').jStepper()
        va.find('input').jStepper() if dateStepper

      scope.$watch 'crit.operator', ((newVal,oldVal) ->
        if scope.crit.datatype=='date' || scope.crit.datatype=='datetime'
          newRel = chainSearchOperators.isRelative(scope.crit.datatype,newVal)
          oldRel = chainSearchOperators.isRelative(scope.crit.datatype,oldVal)
          if newRel != oldRel
            scope.crit.value = ""
        render()
      ), false

      render()
    }
]
@components.service 'chainSearchOperators', [() ->
  {
    isRelative : (datatype, operator) ->
      opList = @.ops[datatype]
      return false unless opList
      op = null
      for o in opList
        op = o if o.operator == operator
      return false unless op
      op.relative

    ops : {
      date: [
        {operator:'eq',label:'Equals'}
        {operator:'nq',label:'Not Equal To'}
        {operator:'gt',label:'After'}
        {operator:'lt',label:'Before'}
        {operator:'bda',label:'Before _ Days Ago',relative:true}
        {operator:'ada',label:'After _ Days Ago',relative:true}
        {operator:'bdf',label:'Before _ Days From Now',relative:true}
        {operator:'adf',label:'After _ Days From Now',relative:true}
        {operator:'pm',label:'Previous _ Months',relative:true}
        {operator:'null',label:'Is Empty'}
        {operator:'notnull',label:'Is Not Empty'}
        ]
      datetime: [
        {operator:'eq',label:'Equals'}
        {operator:'nq',label:'Not Equal To'}
        {operator:'gt',label:'After'}
        {operator:'lt',label:'Before'}
        {operator:'bda',label:'Before _ Days Ago',relative:true}
        {operator:'ada',label:'After _ Days Ago',relative:true}
        {operator:'bdf',label:'Before _ Days From Now',relative:true}
        {operator:'adf',label:'After _ Days From Now',relative:true}
        {operator:'pm',label:'Previous _ Months',relative:true}
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
        {operator:'notin',label:'Not One Of'}
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
        {operator:'notin',label:'Not One Of'}
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
        {operator:'notin',label:'Not One Of'}
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
        {operator:'notin',label:'Not One Of'}
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
        {operator:'notin',label:'Not One Of'}
        {operator:'null',label:'Is Empty'}
        {operator:'notnull',label:'Is Not Empty'}
        ]
      boolean: [
        {operator:'notnull',label:'Yes'}
        {operator:'null',label:'No'}
        ]
      }
    }
]
@components.directive 'chainSearchResult', ['$http',($http) ->
  {
    scope: {
      searchResult:"=chainSearchResult"
      page: "="
      errors:"=",
      notices:"="
      urlPrefix:"@src"
      perPage: "="
      noChrome: "@"
    }
    transclude:true
    templateUrl:'/templates/search_result.html'
    controller: ['$scope',($scope) ->

      $scope.loadedSearchId = null

      $scope.itemsPerPage = 100
      $scope.itemsPerPage = $scope.perPage unless $scope.perPage==undefined or isNaN($scope.perPage)

      #write cookie for current selection state
      writeSelectionCookie = () ->
        o = {rows:$scope.bulkSelected,all:$scope.allSelected}
        $.cookie($scope.urlPrefix+$scope.searchResult.id,JSON.stringify(o))

      #load selection state values from cookie
      readSelectionCookie = (searchId) ->
        v = $.cookie($scope.urlPrefix+searchId)
        if v
          o = $.parseJSON v
          $scope.bulkSelected = o.rows
          $scope.selectAll() if o.all
          for r in $scope.searchResult.rows
            r.bulk_selected = true if $.inArray(r.id,$scope.bulkSelected)>=0

      loadResultPage = (searchId,page) ->
        p = if page==undefined then 1 else page
        $scope.searchResult = {id:searchId}
        $http.get($scope.urlPrefix+searchId+'?page='+p+'&per_page='+$scope.itemsPerPage).success((data,status,headers,config) ->
          $scope.searchResult = data
          $scope.errors.push "Your search was too big.  Only the first 10 pages are being shown." if $scope.searchResult.too_big
          $scope.loadedsearchId = $scope.searchResult.id
          readSelectionCookie data.id
        ).error((data,status) ->
          if status == 404
            $scope.errors.push "This search with id "+id+" could not be found."
          else
           $scope.errors.push "An error occurred while loading this search result. Please reload and try again."
        )

      #return array of valid page numbers for the current search result
      $scope.pageNumberArray = () ->
        if $scope.searchResult && $scope.searchResult.total_pages
          [1..$scope.searchResult.total_pages]
        else
          [1]

      #return true if the given row's id is different than the previous rows id
      $scope.newObjectRow = (idx) ->
        return true if idx==0
        myRowId = $scope.searchResult.rows[idx].id
        lastRowId = $scope.searchResult.rows[idx-1].id
        return myRowId!=lastRowId && idx>0

      #return the classes that should be applied to a result row based on it's position and whether it's the first instance of a new row key
      $scope.classesForRow = (idx) ->
        return [] if idx==0
        r = []
        r.push 'search_row_break' if $scope.newObjectRow(idx)
        r

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
      
      #pagination
      $scope.firstPage = () ->
        $scope.searchResult.page = 1
      
      $scope.lastPage = () ->
        $scope.searchResult.page = searchResult.total_pages

      $scope.nextPage = () ->
        $scope.searchResult.page++

      $scope.previousPage = () ->
        $scope.searchResult.page--

      $scope.$watch 'bulkSelected', ((newValue,oldValue) ->
        writeSelectionCookie() unless newValue==oldValue
      ), true

      $scope.$watch 'allSelected', (newValue,oldValue) ->
        writeSelectionCookie() unless newValue==oldValue

      $scope.$watch 'searchResult', ((newValue,oldValue) ->
        if newValue && newValue.rows
          valsAdded = []
          for r in newValue.rows
            if r.bulk_selected
              unless $.inArray(r.id,$scope.bulkSelected)>=0
                $scope.bulkSelected.push r.id
                valsAdded.push r.id
            else if $.inArray(r.id,valsAdded)==-1
              idx = $.inArray(r.id,$scope.bulkSelected)
              $scope.bulkSelected.splice(idx,1) if idx>=0
              $scope.allSelected = false
        $scope.selectPageCheck = false
        ), true #true means "deep search"

      #
      # End bulk action handling
      #


      $scope.$watch 'searchResult.id', (newVal,oldVal) ->
        loadResultPage(newVal,$scope.page) if newVal!=undefined && !isNaN(newVal) && newVal!=$scope.loadedSearchId
    ]
  }
]

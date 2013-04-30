@components = angular.module 'ChainComponents', []

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
    templateUrl:'templates/chain_messages.html'
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
    templateUrl:"templates/chain_search_criterion.html",
    controller: ['$scope',($scope) ->
      $scope.operators = chainSearchOperators.ops

      # parent controller needs to $watch for deleteMe and do the actual work of removing the object!
      $scope.remove = (crit) ->
        crit.deleteMe = true

      $scope.updateValueHtml = () ->
        
    ],
    link: (scope, el, attrs) ->
      render = () ->
        dateStepper = false #true means apply jStepper to a relative date field
        v_str = "<input type='text' ng-model='crit.value' />"
        switch scope.crit.datatype
          when "string"
            v_str = "<input type='text' ng-model='crit.value' />"
          when "integer", "fixnum", "decimal"
            v_str = "<input type='text' ng-model='crit.value' />"
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

      if scope.crit.datatype=='date' || scope.crit.datatype=='datetime'
        scope.$watch 'crit.operator', ((newVal,oldVal) ->
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

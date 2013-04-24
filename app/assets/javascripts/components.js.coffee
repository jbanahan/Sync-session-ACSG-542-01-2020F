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
            scope.chainDatePicker = $.datepicker.parseDate('yy-mm-dd',text)
        showOn: 'button'
        }
      )
      #add watch to update
  }
]

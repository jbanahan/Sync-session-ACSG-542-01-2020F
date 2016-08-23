app = angular.module('StateToggleButtonApp',['ChainComponents'])

app.factory 'stateToggleButtonSvc', ['$http', ($http) ->
  {
    loadButton: (id) ->
      $http.get('/api/v1/admin/state_toggle_buttons/' + id + '/' + 'edit.json')

    updateButton: (id, params) ->
      $http.put('/api/v1/admin/state_toggle_buttons/' + id, JSON.stringify(params))
  }
]

app.controller 'stateToggleButtonCtrl', ['$scope', '$location', '$window', 'stateToggleButtonSvc', 'chainSearchOperators', ($scope,$location,$window,stateToggleButtonSvc,chainSearchOperators) ->

  $scope.getId = (url) ->
    m = url.match(/\d+(?=\/edit)/)
    m[0] if m

  $scope.loadButton = (id) ->
    p = stateToggleButtonSvc.loadButton id
    p.then (resp) ->
      basicButton = resp["data"]["button"]["state_toggle_button"]
      $scope.stb = 
        module_type: basicButton["module_type"]
        user_attribute: basicButton["user_attribute"]
        user_custom_definition_id: basicButton["user_custom_definition_id"]
        date_attribute: basicButton["date_attribute"]
        date_custom_definition_id: basicButton["date_custom_definition_id"]
        permission_group_system_codes: basicButton["permission_group_system_codes"]
        activate_text: basicButton["activate_text"]
        activate_confirmation_text: basicButton["activate_confirmation_text"]
        deactivate_text: basicButton["deactivate_text"]
        deactivate_confirmation_text: basicButton["deactivate_confirmation_text"]
      
      $scope.searchCriterions = resp["data"]["criteria"]
      $scope.scMfs = resp["data"]["sc_mfs"]
      $scope.userMfs = resp["data"]["user_mfs"]
      $scope.userCdefs = resp["data"]["user_cdefs"]
      $scope.dateMfs = resp["data"]["date_mfs"]
      $scope.dateCdefs = resp["data"]["date_cdefs"]

  $scope.updateButton = (id, params) ->
    p = stateToggleButtonSvc.updateButton id, params
    p.then () ->
      $window.location = '/state_toggle_buttons'

  $scope.resetField = (field) ->
    $scope.stb[field] = null
    
  $scope.saveButton = () ->
    params = {criteria: $scope.searchCriterions, stb: $scope.stb}
    $scope.updateButton($scope.buttonId, params)

  #from advanced_search.js.coffee.erb
  findByMfid = (ary,mfid) ->
    for m in ary
      return m if m.mfid==mfid
    return null

  #adapted from advanced_search.js.coffee.erb
  $scope.addCriterion = (toAddId) ->
    toAdd = {value:''}
    mf = findByMfid $scope.scMfs, toAddId
    toAdd.mfid = mf.mfid
    toAdd.datatype = mf.datatype
    toAdd.label = mf.label
    toAdd.operator = $scope.operators[toAdd.datatype][0].operator
    $scope.searchCriterions.push toAdd

  $scope.operators = chainSearchOperators.ops
  $scope.buttonId = $scope.getId($location.absUrl())
  registrations = []

  #adapted from advanced_search.js.coffee.erb
  $scope.removeCriterion = (crit) ->
    criterions = $scope.searchCriterions
    criterions.splice($.inArray(crit, criterions ),1)

  #adapted from advanced_search.js.coffee.erb
  registrations.push($scope.$watch 'searchCriterions', ((newValue, oldValue, watchScope) ->
      return unless watchScope.searchCriterions && watchScope.searchCriterions.length > 0
      for c in watchScope.searchCriterions
        watchScope.removeCriterion(c) if c && c.deleteMe  # Not sure why, but I've seen console errors due to c being null here.
    ), true
  )

  #from advanced_search.js.coffee.erb
  $scope.$on('$destroy', () ->
      deregister() for deregister in registrations
      registrations = null
    )
]


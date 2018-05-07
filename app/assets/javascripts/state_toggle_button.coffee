app = angular.module('StateToggleButtonApp',['ChainComponents'])

app.factory 'stateToggleButtonMaintSvc', ['$http', ($http) ->
  {
    loadButton: (id) ->
      $http.get('/api/v1/admin/state_toggle_buttons/' + id + '/' + 'edit.json')

    updateButton: (id, params) ->
      $http.put('/api/v1/admin/state_toggle_buttons/' + id, JSON.stringify(params))
  }
]

app.controller 'stateToggleButtonCtrl', ['$scope', '$location', '$window', 'stateToggleButtonMaintSvc', 'chainSearchOperators', ($scope,$location,$window,stateToggleButtonMaintSvc,chainSearchOperators) ->

  $scope.getId = (url) ->
    m = url.match(/\d+(?=\/edit)/)
    m[0] if m

  $scope.loadButton = (id) ->
    p = stateToggleButtonMaintSvc.loadButton id
    p.then (resp) ->
      $scope.stb = resp["data"]["button"]["state_toggle_button"]
      
      $scope.searchCriterions = resp["data"]["criteria"]
      $scope.scMfs = resp["data"]["sc_mfs"]
      $scope.userMfs = resp["data"]["user_mfs"]
      $scope.userCdefs = resp["data"]["user_cdefs"]
      $scope.dateMfs = resp["data"]["date_mfs"]
      $scope.dateCdefs = resp["data"]["date_cdefs"]

  $scope.updateButton = (id, params) ->
    p = stateToggleButtonMaintSvc.updateButton id, params
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


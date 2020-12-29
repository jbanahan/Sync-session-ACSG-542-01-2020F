app = angular.module('OneTimeAlertApp',['ChainComponents'])

app.factory 'oneTimeAlertSvc', ['$http', ($http) ->
  {
    loadAlert: (id) ->
      $http.get('/api/v1/one_time_alerts/' + id + '/' + 'edit.json')

    updateAlert: (id, params) ->
      $http.put('/api/v1/one_time_alerts/' + id, JSON.stringify(params))

    deleteAlert: (id) ->
      $http.delete('/api/v1/one_time_alerts/' + id + '.json')
  }
]

app.controller 'oneTimeAlertCtrl', ['$scope', '$location', '$window', 'oneTimeAlertSvc', 'chainSearchOperators', ($scope,$location,$window,oneTimeAlertSvc,chainSearchOperators) ->

  $scope.getId = (url) ->
    m = url.match(/\d+(?=\/edit)/)
    m[0] if m

  $scope.get_display_param = () ->
    param = $location.absUrl().match(/display_all=true/)
    param[0] if param

  $scope.loadAlert = (id) ->
    p = oneTimeAlertSvc.loadAlert id
    p.then (data) ->
      basicAlert = data["data"]["alert"]["one_time_alert"]
      $scope.alert =
        module_type: basicAlert["module_type"]
        name: basicAlert["name"]
        mailing_list_id: basicAlert["mailing_list_id"]
        email_addresses: basicAlert["email_addresses"]
        email_subject: basicAlert["email_subject"]
        email_body: basicAlert["email_body"]
        expire_date: basicAlert["expire_date"]
        blind_copy_me: basicAlert["blind_copy_me"]
        inactive: basicAlert["inactive"]
      
      $scope.mailingLists = data["data"]["mailing_lists"]
      $scope.searchCriterions = data["data"]["criteria"]
      $scope.modelFields = data["data"]["model_fields"]

  $scope.updateAlert = (id, params) ->
    oneTimeAlertSvc.updateAlert(id, params).then(() ->
        display_param = $scope.get_display_param()
        $window.location = "/one_time_alerts?message=update#{if display_param then '&' + display_param else ''}"
      (data) ->
        $("#error").text(data.data.error)
        $("#alert-update-failure").show()
        $window.scrollTo(0,0))

  $scope.saveAlert = () ->
    display_all = $scope.get_display_param() != null
    params = {criteria: $scope.searchCriterions, alert: $scope.alert, send_test: $scope.send_test, display_all: display_all}
    if $scope.alert.inactive
      return unless $window.confirm "Are you sure you want to leave this alert inactive?"
    $scope.updateAlert($scope.alertId, params)

  $scope.cancelAlert = (id) ->
    p = oneTimeAlertSvc.loadAlert id
    p.then (data) ->
      name = data["data"]["alert"]["one_time_alert"]["name"]
      display_param = $scope.get_display_param()
      url = "/one_time_alerts#{if display_param then '?' + display_param else ''}"
      # if OTA doesn't have a name, infer that user created base record by accident
      if !name || name.length == 0
        oneTimeAlertSvc.deleteAlert(id).then () ->
          $window.location = url
      else
        $window.location = url

  $scope.deleteAlert = (id) ->
    p = oneTimeAlertSvc.deleteAlert id
    display_param = $scope.get_display_param()
    p.then () ->
      $window.location = "/one_time_alerts?message=delete#{if display_param then '&' + display_param else ''}"

  #from advanced_search.js.coffee.erb
  findByMfid = (ary,mfid) ->
    for m in ary
      return m if m.mfid==mfid
    return null

  #adapted from advanced_search.js.coffee.erb
  $scope.addCriterion = (toAddId) ->
    toAdd = {value:''}
    mf = findByMfid $scope.modelFields, toAddId
    toAdd.mfid = mf.mfid
    toAdd.datatype = mf.datatype
    toAdd.label = mf.label
    toAdd.operator = $scope.operators[toAdd.datatype][0].operator
    $scope.searchCriterions.push toAdd

  $scope.operators = chainSearchOperators.ops
  $scope.alertId = $scope.getId($location.absUrl())
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


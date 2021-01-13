MilestoneConfigApp = angular.module('MilestoneConfigApp', ['ChainComponents','ui.router', 'ngSanitize'])
MilestoneConfigApp.config ['$httpProvider', ($httpProvider) ->
  $httpProvider.defaults.headers.common['Accept'] = 'application/json'
  $httpProvider.interceptors.push 'chainHttpErrorInterceptor'
]

MilestoneConfigApp.config ['$stateProvider','$urlRouterProvider',($stateProvider,$urlRouterProvider) ->
  $urlRouterProvider.otherwise('/')

  $stateProvider.
    state('index', {
      url: '/',
      templateUrl: '<%=asset_path("milestone_notification_config/milestone_notification_config_index.html")%>'
      controller: 'MilestoneIndexController'
    }).
    state('show', {
      url: '/:configId/:action'
      templateUrl: '<%=asset_path("milestone_notification_config/milestone_notification_config_show.html")%>'
      controller: 'MilestoneShowController'
    }).
    state('new', {
      url: '/new'
      templateUrl: '<%=asset_path("milestone_notification_config/milestone_notification_config_show.html")%>'
      controller: 'MilestoneShowController'
    })
]

angular.module('MilestoneConfigApp').factory 'milestoneSvc', ['$http', ($http) ->

  milestonePath = (suffix) ->
    '/api/v1/admin/milestone_notification_configs' + suffix + '.json'

  milestoneHandler = (resp) ->
    resp.data

  return {
    getMilestoneUpdateConfig: (configId) ->
      if configId
        $http.get(milestonePath('/' + configId)).then(milestoneHandler)
      else
        $http.get(milestonePath('/new')).then(milestoneHandler)

    getMilestoneUpdateConfigs: () ->
      $http.get(milestonePath(''))

    saveMilestoneUpdate: (ms) ->
      config_param = {milestone_notification_config: ms}
      if ms.id && ms.id > 0
        $http.put(milestonePath('/' + ms.id), config_param).then(milestoneHandler)
      else
        $http.post(milestonePath(''), config_param).then(milestoneHandler)

    copyMilestoneUpdateConfig: (configId) ->
      $http.get(milestonePath('/' + configId + '/copy')).then(milestoneHandler)

    getModelFields: (module_type) ->
      $http.get(milestonePath('/model_fields') + '?module_type='+module_type).then(milestoneHandler)

  }
]

# If we're using a filter only show those fields, otherwise show everything.
MilestoneConfigApp.filter "includeOnly", () ->
  (data, filterType) ->
    data.filter (mf) ->
      if filterType
        return filterType in mf.filters
      else
        true

MilestoneConfigApp.controller 'MilestoneIndexController', ['$scope', 'milestoneSvc', '$state', 'chainErrorHandler', ($scope, milestoneSvc, $state, chainErrorHandler) ->

  $scope.errorHandler = chainErrorHandler
  $scope.errorHandler.responseErrorHandler = (rejection) ->
    $scope.milestoneConfigs = null

  $scope.loadingFlag = "loading"

  milestoneSvc.getMilestoneUpdateConfigs().then((resp) ->
    $scope.milestoneConfigs = resp.data.configs
    $scope.outputStyles = resp.data.output_styles
    $scope.moduleTypes = resp.data.module_types
    $scope.loadingFlag = null
  )

  $scope.showConfig = (config) ->
    $scope.errorHandler.clear()
    $state.go('show', {configId: config.id, action: "show"})

  $scope.newConfig = ()->
    $scope.errorHandler.clear()
    $state.go('new')

  $scope.outputStyle = (fmt) ->
    $scope.outputStyles[fmt]
]

MilestoneConfigApp.controller 'MilestoneShowController', ['$scope', 'milestoneSvc', '$state', 'chainErrorHandler', ($scope, milestoneSvc, $state, chainErrorHandler) ->

  $scope.loadingFlag = "loading"
  $scope.errorHandler = chainErrorHandler
  $scope.customerNumberDisplayed = true

  $scope.errorHandler.responseErrorHandler = (rejection) ->
    $scope.loadingFlag = null

  responseHandler = (resp) ->
    $scope.config = resp.config.milestone_notification_config
    # Set the customer number display flag to true if there's a non-blank customer number
    if $scope.config.customer_number
      $scope.customerNumberDisplayed = true
    else
      $scope.customerNumberDisplayed = false

    $scope.modelFieldList = resp.model_field_list
    $scope.eventList = resp.event_list
    $scope.outputStyles = resp.output_styles
    $scope.moduleTypes = resp.module_types
    $scope.timezones = resp.timezones
    $scope.loadingFlag = null

  if $state.params.action == "copy"
    milestoneSvc.copyMilestoneUpdateConfig($state.params.configId).then(responseHandler)
  else
    milestoneSvc.getMilestoneUpdateConfig($state.params.configId).then(responseHandler)

  $scope.saveConfig = () ->
    $scope.loadingFlag = "loading"
    # Based on the value of the customer number / parent system code displayed flag, we'll want to strip
    # out the value in the corresponding config value...as only one of customer number / parent system code
    # should be allowed at a time.
    if $scope.customerNumberDisplayed
      $scope.config.parent_system_code = null
    else
      $scope.config.customer_number = null

    milestoneSvc.saveMilestoneUpdate($scope.config).then( (resp) ->
      $scope.errorHandler.clear()
      $scope.showIndex()
    )

  $scope.filterType = () ->
    if RegExp('tradelens').test $scope.config.output_style
      'tradelens'

  $scope.cancel = () ->
    $scope.showIndex()

  $scope.showIndex = () ->
    $scope.config = null
    $state.go('index')

  $scope.newEvent = () ->
    $scope.config.setup_json.milestone_fields.push {}

  $scope.copyConfig = () ->
    id = $scope.config.id
    $scope.config = null
    $state.go('show', {configId: id, action: "copy"})

  $scope.removeEvent = (event) ->
    $scope.config.setup_json.milestone_fields = $scope.config.setup_json.milestone_fields.filter (s) ->
      s.model_field_uid != event.model_field_uid

  $scope.getModelFields = () ->
    milestoneSvc.getModelFields($scope.config.module_type).then( (resp) ->
      $scope.modelFieldList = resp.model_field_list
      $scope.eventList = resp.event_list
    )

  $scope.addFingerprintField = () ->
    $scope.config.setup_json.fingerprint_fields.push ""

  $scope.removeFingerprintField = (field) ->
    $scope.config.setup_json.fingerprint_fields = $scope.config.setup_json.fingerprint_fields.filter (s) ->
      s != field

  $scope.toggleCustomerNumber = () ->
    $scope.customerNumberDisplayed = false

  $scope.toggleParentSystemCode = () ->
    $scope.customerNumberDisplayed = true

]
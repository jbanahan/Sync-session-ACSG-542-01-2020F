app = angular.module('CustomViewTemplateApp',['ChainComponents'])

app.factory 'customViewTemplateSvc', ['$http', ($http) ->
  {
    loadTemplate: (id) ->
      $http.get('/api/v1/admin/custom_view_templates/' + id + '/' + 'edit.json')

    updateTemplate: (id, params) ->
      $http.put('/api/v1/admin/custom_view_templates/' + id, JSON.stringify(params))
  }
]

app.controller 'customViewTemplateCtrl', ['$scope', '$location', '$window', 'customViewTemplateSvc', 'chainSearchOperators', ($scope,$location,$window,customViewTemplateSvc,chainSearchOperators) ->

  $scope.getId = (url) ->
    m = url.match(/\d+(?=\/edit)/)
    m[0] if m

  $scope.loadTemplate = (id) ->
    p = customViewTemplateSvc.loadTemplate id
    p.then (data) ->
      basicTemplate = data["data"]["template"]["custom_view_template"]
      $scope.cvt =
        template_identifier: basicTemplate["template_identifier"]       
        template_path: basicTemplate["template_path"]
        module_type: basicTemplate["module_type"]
      
      $scope.searchCriterions = data["data"]["criteria"]
      $scope.modelFields = data["data"]["model_fields"]

  $scope.updateTemplate = (id, params) ->
    p = customViewTemplateSvc.updateTemplate id, params
    p.then () ->
      $window.location = '/custom_view_templates'

  $scope.saveTemplate = () ->
    params = {criteria: $scope.searchCriterions, cvt: $scope.cvt}
    $scope.updateTemplate($scope.templateId, params)

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
  $scope.templateId = $scope.getId($location.absUrl())
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

